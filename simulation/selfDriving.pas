{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}

unit selfDriving;

interface

uses sysutils, crt, INSACAR_TYPES, dateutils, SDL, tools, selfDrivingThread, syncobjs;

procedure SD_load(var infoPartie: T_GAMEPLAY; var fenetre: T_UI_ELEMENT);
procedure SD_network(infoPartie: T_GAMEPLAY; fenetre: T_UI_ELEMENT);
procedure SD_message(endpoint: Integer; m: String; infoPartie: T_GAMEPLAY);
procedure SD_input_handler(var infoPartie: T_GAMEPLAY; var e: TSDLKey);
procedure SD_debug(log: String);
procedure SD_setPositionStart(circuit: Integer; var physique: P_PHYSIQUE_ELEMENT);

const C_DEBUG = False;

implementation
type
	T_POS = record 
		x,y,a: Integer;
	end;
	
const C_MAX_VIEWSIGHT = 1000; //Distance de vue max, en nombre de norme

	  C_POSITIONS : array [0..20] of T_POS = ( //Points de spawn du circuit 4
		(x:950;y:1025;a:78),
		(x:290;y:530;a:-18),
		(x:1300;y:568;a:-89),
		(x:3140;y:144;a:-97),
		(x:3882;y:625;a:-171),
		(x:3026;y:1030;a:-346),
		(x:3290;y:523;a:-285),
		(x:2287;y:716;a:-190),
		(x:3020;y:1454;a:-109),
		(x:2538;y:1896;a:-264),
		(x:1585;y:1548;a:-12),
		(x:480;y:931;a:77),
		(x:390;y:326;a:-31),
		(x:3656;y:297;a:-113),
		(x:3011;y:946;a:-351),
		(x:3307;y:732;a:-64),
		(x:2450;y:541;a:-241),
		(x:3641;y:1876;a:-152),
		(x:3551;y:2031;a:-287),
		(x:320;y:1958;a:-271),
		(x:260;y:1742;a:-62)
	  );

procedure SD_input_handler(var infoPartie: T_GAMEPLAY; var e: TSDLKey);
begin
	case e of //Inverse la variable
		SDLK_F1: infoPartie.sd.config.map := not infoPartie.sd.config.map;
		SDLK_F2: infoPartie.sd.config.render := not infoPartie.sd.config.render;
	end;
end;

procedure SD_debug(log: String);
begin
	if C_DEBUG then
		speedWrite(log); //Ecrit dans la console
end;

procedure SD_setPositionStart(circuit: Integer; var physique: P_PHYSIQUE_ELEMENT);
begin
	//Placement voiture au départ de chaque circuit
	case circuit of 	
		1 : 
		begin
			physique^.x := 150;
			physique^.y := 1100;
			physique^.a := 15;
		end;
		
		2 :
		begin
			physique^.x := 700;
			physique^.y := 1030;
			physique^.a := 90;
		end;
		
		3 :
		begin
			physique^.x := 120;
			physique^.y := 575;
			physique^.a := 0;
		end;
		
		4 :
		begin
			physique^.x := 950;
			physique^.y := 1025;
			physique^.a := 78;
		end;
	end;
end;

function setPoint(var map: PSDL_Surface; px,py : Real; vx,vy: Integer): SDL_Rect; //Renvoie la distance entre (p) & le 1er pixel vert sur la droite de paramètre (v).
var stop: Boolean;
	i: Integer;
	pixel: TSDL_Color;
begin
	stop := True;
	i:=0;
	setPoint.x:=Round(px);
	setPoint.y:=Round(py);
	setPoint.w := 10;
	setPoint.h := 10;
	
	while(stop AND (i<C_MAX_VIEWSIGHT)) do //Si on a trouvé ou on a atteind le max ( i*norme(vx,vy) )
	begin
		//On se balade sur la droite
		setPoint.x := setPoint.x+vx;
		setPoint.y := setPoint.y+vy;
		
		//Couleur du pixel
		pixel := pixel_get(map, setPoint.x, setPoint.y);

		//Si le pixel est vert
		stop := not ((pixel.r = 57) AND (pixel.g = 181) AND (pixel.b = 74));

		i := i+1;
	end;
end;


procedure setPoints(var infoPartie: T_GAMEPLAY; var fenetre: T_UI_ELEMENT);
var hit : TSDL_Rect;
	i,j,k, hitPoint: integer;
	ca,sa : Real;

begin
	//Optimisation du sinus/cosinus
	sa:=sin(180--3.141592/180*infoPartie.joueurs.t[0].voiture.physique^.a);
	ca:=cos(180--3.141592/180*infoPartie.joueurs.t[0].voiture.physique^.a);
	
	//8-16 => 1-2
	hitPoint := infoPartie.sd.config.hitPoint DIV 8;
	
	k:=0;
	for i:=-hitPoint to hitPoint do //On génère les points
		for j:=-hitPoint to hitPoint do
			if not (sqrt(i*i+j*j)<hitPoint) then //On garde seulement les points du cercle sqrt(2) 
			begin
				//On calcule la position du marqueur
				hit := setPoint(infoPartie.map^.surface, infoPartie.joueurs.t[0].voiture.physique^.x, infoPartie.joueurs.t[0].voiture.physique^.y, Round(5*(i*ca+j*sa)), Round(5*(-i*sa+j*ca))); //x5 car on veut traiter uniquement des entiers
				
				//Positions des marqueurs
				infoPartie.sd.marqueurs[k]^.etat.x := Round(hit.x+fenetre.enfants.t[0]^.etat.x - fenetre.enfants.t[0]^.etat.w/2); 
				infoPartie.sd.marqueurs[k]^.etat.y := Round(hit.y+fenetre.enfants.t[0]^.etat.y - fenetre.enfants.t[0]^.etat.h/2);
				k:=k+1;
			end;
end;

procedure SD_Movement(var infoPartie: T_GAMEPLAY; m: T_SD_Message);
begin
	//0,0,0,0,0,0
	//G,R,D,AV,R,AR
	//1,3,5,7 ,9,11


	//Vitesse
	if m.payload[7] = '1' then
		infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr - infoPartie.temps.dt*infoPartie.sd.config.coef.avant //AVANT
	else if (m.payload[11] = '1') then
		if (infoPartie.joueurs.t[0].voiture.physique^.dr < 0) then
			infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr + infoPartie.temps.dt*infoPartie.sd.config.coef.arriere //FREIN
		else
			infoPartie.joueurs.t[0].voiture.physique^.dr := 0; //PAS DE MARCHE ARRIERE
	
	//Direction
	if m.payload[1] = '1' then
		infoPartie.joueurs.t[0].voiture.physique^.a := infoPartie.joueurs.t[0].voiture.physique^.a + infoPartie.temps.dt*infoPartie.sd.config.coef.alpha
	else if m.payload[5] = '1' then
		infoPartie.joueurs.t[0].voiture.physique^.a := infoPartie.joueurs.t[0].voiture.physique^.a - infoPartie.temps.dt*infoPartie.sd.config.coef.alpha;

end;

procedure SD_setPosition(voiture: P_PHYSIQUE_ELEMENT); //Position aléatoire carte 4
var p : T_POS;
	r1, r2: Integer;
begin
	//deux random
	r1 := random(21);
	r2 := random(2);
	
	//Position aléatoire
	p := C_POSITIONS[r1];
	
	//On assigne la position
	voiture^.x := p.x;
	voiture^.y := p.y;
	
	//On assigne l'angle (+/- 180°)
	voiture^.a := p.a + 180*r2; //Deux sens possible
end;

procedure SD_Reset(var infoPartie: T_GAMEPLAY);
begin
	SD_debug('reset1');
	
	//Vitesse initiale
	infoPartie.joueurs.t[0].voiture.physique^.dr := -infoPartie.sd.config.vitesseDepart*2.5;
	SD_debug('reset2');
	
	//Position initiale
	if infoPartie.sd.config.safeSpawn then
		SD_setPositionStart(infoPartie.sd.config.circuit,infoPartie.joueurs.t[0].voiture.physique)
	else
		SD_setPosition(infoPartie.joueurs.t[0].voiture.physique);
		
	SD_debug('reset3');
	
	//On inverse le drapeau
	infoPartie.sd.server._reset := False;
	SD_debug('reset4');
	
	//Envoyer le message envOK
	infoPartie.sd.server.sendMessage(1, 'ok');
	writeln('Reset ok');
end;

procedure SD_message(endpoint: Integer; m: String; infoPartie: T_GAMEPLAY);
begin
	//Envoyer le message
	infoPartie.sd.server.sendMessage(endpoint, m);
end;

procedure SD_network(infoPartie: T_GAMEPLAY; fenetre: T_UI_ELEMENT);
var payload : String;
	i, vx, vy, distance : Integer;
	f : SDL_Rect;
	ok : LongInt;
	m : T_SD_Message;
begin
	SD_Debug('network1');
	
	//Trouver les marqueurs
	setPoints(infoPartie, fenetre);	
	SD_Debug('network2');
	
	//Preparer message reseau (etat)
	payload := concat(intToStr(infoPartie.sd.config.hitPoint), '/');
	
	//Position de la voiture (x,y)
	vx := Round(infoPartie.joueurs.t[0].voiture.physique^.x);
	vy := Round(infoPartie.joueurs.t[0].voiture.physique^.y);
	
	//Position de la carte du circuit
	f := fenetre.enfants.t[0]^.etat;
	SD_Debug('network3');
	
	for i:=0 to infoPartie.sd.config.hitPoint-1 do
	begin
		//Calcul distance (centreVoiture-Marqueur)
		distance := round(sqrt((infoPartie.sd.marqueurs[i]^.etat.x - f.x - vx)*(infoPartie.sd.marqueurs[i]^.etat.x - f.x - vx)+(infoPartie.sd.marqueurs[i]^.etat.y - f.y - vy)*(infoPartie.sd.marqueurs[i]^.etat.y - f.y - vy)));
		
		//On ajoute l'information au message
		payload:= concat(payload, intToStr(distance-10), ';'); //-10 pour centrer
	end;
	SD_Debug('network4');
	
	//Fin du message etat: Vitesse de la voiture
	payload := concat(payload, '/', intToStr(Round(-infoPartie.joueurs.t[0].voiture.physique^.dr/2.5)));
	
	
	//Envoyer le message
	SD_message(2, payload, infoPartie);
	SD_Debug('network5');
	
	
	//Traitement messages recu
	ok := 0;
	while ok = 0 do
	begin
		//On test si l'on a un message de déplacement
		infoPartie.sd.server.getMessageMvt(m, ok);
		
		//On effectue le mouvement
		if ok = 0 then
			SD_Movement(infoPartie, m);
	end;
	SD_Debug('network6');
	
	//Si le drapeau reset est activé, on reset
	if infoPartie.sd.server._reset then
	begin
		writeln('Start Reset');
		SD_Reset(infoPartie);
	end;
	SD_Debug('network7');
end;

procedure SD_load(var infoPartie: T_GAMEPLAY; var fenetre: T_UI_ELEMENT);
var	i : Integer;
begin
	//Initialise le random
	Randomize();
	
	//On crée un lock & le thread serveur
	infoPartie.sd.lock := TCriticalSection.Create();
	infoPartie.sd.server := T_ThreadServer.Create(True, '127.0.0.1', 25565, infoPartie.sd.lock);
	
	//On lance le thread serveur
	infoPartie.sd.server.Start();

	//Memoire pour afficher les marqueurs
	GetMem(infoPartie.sd.marqueurs, infoPartie.sd.config.hitPoint*SizeOf(P_UI_ELEMENT));

	//Init Marqueurs
	for i:=0 to infoPartie.sd.config.hitPoint-1 do
	begin
		ajouter_enfant(fenetre);
		fenetre.enfants.t[fenetre.enfants.taille-1]^.typeE := couleur;
		fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.w := 10;
		fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.h := 10;
		fenetre.enfants.t[fenetre.enfants.taille-1]^.surface := SDL_CreateRGBSurface(0, fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.w, fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.h, 32, 0,0,0,0);
		fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.x := 10*i; //Affichage initial en ligne
		fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.y := 10;
		fenetre.enfants.t[fenetre.enfants.taille-1]^.couleur.b := Round((255/infoPartie.sd.config.hitPoint)*i); //Dégradé
		fenetre.enfants.t[fenetre.enfants.taille-1]^.couleur.r := Round((255/infoPartie.sd.config.hitPoint)*(infoPartie.sd.config.hitPoint-i));
		fenetre.enfants.t[fenetre.enfants.taille-1]^.style.enabled := False; //Pas de rendu alpha
		infoPartie.sd.marqueurs[i] := fenetre.enfants.t[fenetre.enfants.taille-1];
	end;

	//Message envOK
	SD_message(1, 'Init OK', infoPartie);
end;

begin
end.

