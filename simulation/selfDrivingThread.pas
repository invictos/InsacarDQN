{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}

unit selfDrivingThread;

{$mode objfpc}

interface

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  Classes, Sockets, sysutils, dateutils, Windows, crt, syncobjs;
 
const 	C_SD_Messages_MAXSIZE = 10; //Queue limite
		C_BUFFER_MAXSIZE = 512; //Max TCP buffer Size
		
Type
	T_SD_Message = record
		endpoint : Integer;
		payload : String;
		ts1, ts2, ts3 : int64; //SEND: ts1: add stack / RECV: ts1: bufferTS,ts2: Processed time, ts3: Stack Out
	end;
	P_SD_Message = ^T_SD_Message;
	
	T_SD_Messages = record //FIFO
		t : ^P_SD_Message;
		length : Integer;
	end;	
	
	T_BUFFER = array[0..C_BUFFER_MAXSIZE-1] of char;
	
	T_PACKETS = array of String;
	
	T_ThreadServer = class(TThread) //Thread pour serveur TCP
		private
			_socket : LongInt; //Socket
			_recvQueueMvt : T_SD_Messages;
			_ip : String;
			_port : Integer;
			_lock : TCriticalSection;
			
			_decode_buffer : String;
			_decode_size : Integer;
			_decode_isSize : Boolean;
			
		protected
			procedure Execute; override;
		public
			_reset : boolean; //Atomique
			constructor Create(autoStart : boolean; ip: String; port: Integer; var lock: TCriticalSection);
			procedure processPacket(packet: String);
			procedure sendMessage(endpoint: Integer; payload: String);
			procedure getMessageMvt(var m : T_SD_Message; var ok: Integer);
			procedure decodePackets(var readBuffer: T_BUFFER; readSize: Integer; var m: T_PACKETS);
	end;
	
implementation

procedure FsocketError(const S:string);
begin
  writeln (S,SocketError);
  halt(100);
end;

procedure SD_Messages_shift(var messages: T_SD_Messages; var m : T_SD_Message; var ok : Integer);
var i : Integer;
	old : ^P_SD_Message;
begin
	ok := 0;
	if messages.length = 0 then
		ok := 1
	else
	begin
		//Old pointer
		old := messages.t; 
		
		//Pointer to message
		m := messages.t[0]^; 
		
		// New block of mem
		GetMem(messages.t, (messages.length-1)*sizeOf(P_SD_Message)); 
		
		//Fill mem block
		for i:=0 to messages.length-2 do
			messages.t[i] := old[i+1];	
		
		//Free mem
		FreeMem(old[0], sizeOf(T_SD_Message));
		FreeMem(old, messages.length*sizeOf(P_SD_Message));

		//Decrease size
		messages.length := messages.length-1; 
	end;
end;

procedure SD_Messages_push(var messages: T_SD_Messages; m : P_SD_Message; var ok : Integer);
var old : ^P_SD_Message;
	i: Integer;
begin
	ok := 0;
	if messages.length = C_SD_Messages_MAXSIZE then
		ok := 1
	else
	begin
		//Old pointer
		old := messages.t; 
		
		//New block of mem
		GetMem(messages.t, (messages.length+1)*sizeOf(P_SD_Message));
		
		//Fill mem block
		for i:=0 to messages.length-1 do
			messages.t[i] := old[i];
		
		//Free mem
		FreeMem(old, messages.length*sizeOf(P_SD_Message));
		
		//New element
		messages.t[messages.length] := m;
		messages.length := messages.length + 1;
	end;
end;

procedure speedWrite(chaine: String);
var tmp: LongWord;
	s: String;
begin
	if True then
	begin
		{$IFDEF WIN32} //compilation conditionnelle: Si Windows Alors
			s := chaine+LineEnding;
			WriteConsole(GetStdHandle(STD_OUTPUT_HANDLE), @s[1], LongWord(s[0]), tmp, nil); //https://docs.microsoft.com/en-us/windows/console/writeconsole
		{$ELSE} //Sinon
			write(chaine);
		{$ENDIF}
	end;
end;


constructor T_ThreadServer.Create(autoStart : boolean; ip: String; port: Integer; var lock: TCriticalSection);
var	networkAddr : TInetSockAddr;
	listenSocket : LongInt;
begin
	inherited Create(autoStart);
	FreeOnTerminate := True; //Libère la mémoire a la fin du thread
	
	//Init
	_ip := ip;
	_port := port;
	_lock := lock;
	
	_decode_buffer := '';
	_decode_size := 0;
	_decode_isSize := True;
	
	//AF_INET Params
	networkAddr.sin_addr := strToNetAddr(_ip);
	networkAddr.sin_port := htons(_port);
	networkAddr.sin_family := AF_INET; //AF_INET
	
	//Ecouter sur le reseau AF_INET
	listenSocket := fpSocket(AF_INET, SOCK_STREAM, 0);

	//Bind AF_INET à socket
	if fpBind(listenSocket, @networkAddr, sizeof(networkAddr)) = -1 then
		FSocketError('Server : Bind : ');
	
	//Ecoute sur la socket
	if fpListen(listenSocket,1) = -1 then
		FSocketError('Server : Listen : ');
		
	Writeln('Socket Listening, waiting client'); 
	
	//Attendre un client (bloquant)
	_socket := fpAccept(listenSocket, NIL, NIL);

	//Si erreur client
	if _socket = -1 then
		FSocketError('Server : Accept : ');
		
	//Fermer la socket d'ecoute
	if closeSocket(listenSocket) = -1 then
		FSocketError('Server : Close : ');

	//Init queue action
	_recvQueueMvt.length := 0;
	writeln('Thread : Created');
end;
	
procedure T_ThreadServer.Execute;
var readBuffer : T_BUFFER;
	readSize : LongInt;
	packets : T_PACKETS;
	i : Integer;
begin
	writeln('Thread : Launching');
	try
		while (not Terminated) do //Main loop
		begin
			//Init readBuffer
			readBuffer := '';
			setLength(packets, 0);
			
			//Lire flux données
			readSize := fpRecv(_socket, @readBuffer, C_BUFFER_MAXSIZE, 0);

			//Si lecture ok
			if (readSize > 0) then //Valid data => Answer
			begin
				//On decode le paquet
				decodePackets(readBuffer, readSize, packets);
				
				//On traite le message
				for i:=0 to length(packets)-1 do
					ProcessPacket(packets[i]);

			end
			else if readSize = 0 then // Connection closed
				FSocketError('Server : Connection closed :')
			else //General error
				FSocketError('Server : Connection failed : ');
		end;
	except //Debug les erreurs silencieuses
		on E: Exception do 
			writeln('Thread general error: ', E.message);
	end;
	writeln('Thread : End');
end;

procedure T_ThreadServer.decodePackets(var readBuffer: T_BUFFER; readSize: Integer; var m: T_PACKETS);
var i : Integer;
begin
	//On parcours le flux de char
	for i:=0 to readSize-1 do
	begin
		if(readBuffer[i] = '$') then //On a trouvé un $
		begin
			if _decode_isSize then //On a fini de lire la taille
			begin
				_decode_size := strToInt(_decode_buffer);
				_decode_isSize := False;
				_decode_buffer := '';
			end
			else
			begin //On a fini de lire le message
				if(length(_decode_buffer) = _decode_size )then
				begin
					setLength(m, length(m)+1);
					m[length(m)-1] := _decode_buffer;
				end
				else //Controle taille du message
				begin
					writeln('Error DecodePacket size', _decode_buffer, '/',intToStr(length(_decode_buffer)),'/', IntToStr(_decode_size),'.');
				end;
				//Reset buffer / flag
				_decode_isSize := True;
				_decode_buffer := '';
			end
		end
		else
		begin //On lit un caractère
			_decode_buffer := concat(_decode_buffer, readBuffer[i]);
		end;
	end;
end;

procedure T_ThreadServer.processPacket(packet: String);
var tmp : String;
	ok , i, mode: Integer; //Mode: 0=time, 1=endpoint, 2=payload
	m : P_SD_Message;
begin
	//Init le nouveau message
	getMem(m, SizeOf(T_SD_Message));
	m^.payload := '';
	m^.ts2 := MilliSecondsBetween(Now, 0); //Process time
	
	//Init
	tmp := '';
	mode := 0;

	//On parcours le message
	for i:=1 to length(packet) do
	begin
		if (packet[i] = '/') AND (mode < 2) then //On detecte le separateur & en fonction du mode
		begin
			if mode = 0 then
				m^.ts1 := strToInt64(tmp) //Decoder le timestamp
			else
				m^.endpoint := strToInt(tmp); //Decoder l'endpoint
			
			//Reset buffer, changement flag
			mode := mode + 1;
			tmp := '';
		end
		else if mode < 2 then
			tmp := tmp + packet[i] //Buffer lecture ts/endpoint
		else
			m^.payload := m^.payload + packet[i]; //buffer data direct
	end;

	if m^.endpoint = 0 then //Debug
	begin
		writeln('debug: ', m^.payload);
		FreeMem(m, SizeOf(T_SD_Message));
	end
	else if m^.endpoint = 5 then //Reset car
	begin
		_reset := True;
		writeln('Reset Set');
		FreeMem(m, SizeOf(T_SD_Message));
	end
	else if (m^.endpoint = 4) AND (NOT _reset) then //Mouvement payload
	begin
		_lock.Acquire(); //Sync
		try
			//Ajoute a la queue action
			SD_Messages_push(_recvQueueMvt, m, ok)
		Finally
			_lock.Release(); //Fin sync
		end;
		
		//Si queue pleine
		if ok <> 0 then
		begin
			writeln('RecvQueue full');
			FreeMem(m, SizeOf(T_SD_Message));
		end;
	end
	else 
	begin //On drop le reste
		writeln('ongoing Reset, ep:', intToStr(m^.endpoint));
		FreeMem(m, SizeOf(T_SD_Message));
	end;
end;

procedure T_ThreadServer.sendMessage(endpoint: Integer; payload: String);
var sendBuffer : T_BUFFER;
	sendSize : LongInt;
	packet : String;
begin
	//on forme le message
	payload := concat(intToStr(MilliSecondsBetween(Now, 0)), '/', intToStr(endpoint), '/', payload);
		
	//On forme le paquet
	packet := concat(intToStr(length(payload)), '$', payload, '$');
	
	// ~cast
	sendBuffer := packet;
	
	//Envoyer les données
	sendSize := fpSend(_socket, @sendBuffer, length(packet), 0);
	
	//Erreur envoie
	if sendSize = -1 then
		FSocketError('Server : Send Failed : ');

end;

procedure T_ThreadServer.getMessageMvt(var m : T_SD_Message; var ok: Integer);
begin
	//Sync
	_lock.Acquire();
	try
		//recupère un element (FIFO)
		SD_Messages_shift(_recvQueueMvt, m, ok)
	finally
		_lock.Release();
	end;
	
	//On a un message
	if ok = 0 then
		m.ts3 := MilliSecondsBetween(Now, 0);
end;

begin
end.

