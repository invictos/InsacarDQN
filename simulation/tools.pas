{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}
 
unit tools;
 
interface
uses sdl, sdl_image, sdl_ttf, sysutils, INSACAR_TYPES {$IFDEF WIN32},Windows{$ENDIF};

function seconde_to_temps(t: LongInt): String;
procedure ajouter_physique(var physique: T_PHYSIQUE_TABLEAU);
procedure ajouter_enfant(var element: T_UI_ELEMENT);
function hitBox(surface: PSDL_Surface; p: SDL_Rect; a: Real; colors: array of TSDL_Color): T_HITBOX_COLOR;
function isSameColor(a: TSDL_Color; b: TSDL_Color): Boolean;
procedure imageLoad(chemin: String; var surface: PSDL_Surface; alpha: Boolean);
procedure freeUiElement(var element: T_UI_ELEMENT);
procedure freeInfoPartie(var infoPartie: T_GAMEPLAY);

function pixel_get(surface: PSDL_Surface; x,y: Integer): TSDL_Color;

procedure speedWrite(chaine: String); //Affichage console lent sur Windows. Patch via Windows.h

implementation

procedure speedWrite(chaine: String);
var tmp: LongWord;
begin
	chaine := concat(chaine, LineEnding);
	{$IFDEF WIN32} //compilation conditionnelle: Si Windows Alors
		WriteConsole(GetStdHandle(STD_OUTPUT_HANDLE), @chaine[1], LongWord(chaine[0]), tmp, nil); //https://docs.microsoft.com/en-us/windows/console/writeconsole
	{$ELSE} //Sinon
		write(chaine);
	{$ENDIF}
end;

function seconde_to_temps(t: LongInt): String;
var m,s,ms: Integer;
	tm, ts, tms: String;
begin
	//Minutes
	m:= t DIV 60000;
	
	//Secondes
	s:= (t MOD 60000) DIV 1000;
	
	//Millisecondes
	ms:= t MOD 1000;
	
	if m < 9 then
		tm := concat('0', intToStr(m))
	else
		tm := intToStr(m);
		
	if s < 9 then
		ts := concat('0', intToStr(s))
	else
		ts := intToStr(s);
		
	if ms < 100 then
		if ms<10 then
			tms := concat('00', intToStr(ms))
		else
			tms := concat('0', intToStr(ms))
	else
		tms := intToStr(ms);
	//Texte
	seconde_to_temps := concat(tm, '.', ts, '.', tms);
end;

procedure ajouter_physique(var physique: T_PHYSIQUE_TABLEAU);
var old: ^P_PHYSIQUE_ELEMENT;
	oldExiste: Boolean;
	i: Integer;
begin
	//Sauvegarde ancien pointeur
	oldExiste := physique.t<>NIL;
	
	if oldExiste then
		old:=physique.t;
	
	//Récuperation mémoire
	physique.t := GetMem((physique.taille+1)*SizeOf(P_PHYSIQUE_ELEMENT));
	
	//Ancien élement dans nouveau tableau
	for i:=0 to physique.taille-1 do
		physique.t[i]:=old[i];
	
	//Initialisation élement
	physique.t[physique.taille] := GetMem(SizeOf(T_PHYSIQUE_ELEMENT));
	physique.t[physique.taille]^.x := 0;
	physique.t[physique.taille]^.y := 0;
	physique.t[physique.taille]^.a := 0;
	physique.t[physique.taille]^.r := 0;
	physique.t[physique.taille]^.dr :=0;
	
	//Libération ancienne mémoire
	if oldExiste then
		Freemem(old, physique.taille*SizeOf(P_PHYSIQUE_ELEMENT));
	
	//Incrémentation taille tableau
	physique.taille:=physique.taille+1;
end;

procedure ajouter_enfant(var element: T_UI_ELEMENT);
var old: ^P_UI_ELEMENT;
	oldExiste: Boolean;
	i: Integer;
begin
	//Sauvegarde ancien pointeur
	oldExiste := element.enfants.t<>NIL;
	
	if oldExiste then
		old:=element.enfants.t;

	//Récuperation mémoire
	element.enfants.t := GetMem((element.enfants.taille+1)*SizeOf(P_UI_ELEMENT));
	
	//Ancien élement dans nouveau tableau
	for i:=0 to element.enfants.taille-1 do
		element.enfants.t[i]:=old[i];
		
	//Initialisation élement
	element.enfants.t[element.enfants.taille] := GetMem(SizeOf(T_UI_ELEMENT));
	element.enfants.t[element.enfants.taille]^.etat.x := 0;
	element.enfants.t[element.enfants.taille]^.etat.y := 0;
	element.enfants.t[element.enfants.taille]^.etat.w := 0;
	element.enfants.t[element.enfants.taille]^.etat.h := 0;
	element.enfants.t[element.enfants.taille]^.surface := NIL;
	element.enfants.t[element.enfants.taille]^.typeE := null;
	element.enfants.t[element.enfants.taille]^.valeur:='';
	element.enfants.t[element.enfants.taille]^.couleur.r:=0;
	element.enfants.t[element.enfants.taille]^.couleur.g:=0;
	element.enfants.t[element.enfants.taille]^.couleur.b:=0;
	element.enfants.t[element.enfants.taille]^.style.a:=255;
	element.enfants.t[element.enfants.taille]^.style.enabled:=True;
	element.enfants.t[element.enfants.taille]^.style.display:=True;
	element.enfants.t[element.enfants.taille]^.style.blit:=True;
	element.enfants.t[element.enfants.taille]^.enfants.taille:=0;
	element.enfants.t[element.enfants.taille]^.enfants.t:=NIL;
	element.enfants.t[element.enfants.taille]^.parent := @element;
	
	//Libération ancienne mémoire
	if oldExiste then
		Freemem(old, element.enfants.taille*SizeOf(P_UI_ELEMENT));
	
	//Incrémentation taille tableau
	element.enfants.taille:=element.enfants.taille+1;
end;


function pixel_get(surface: PSDL_Surface; x,y: Integer): TSDL_Color;
var pixels : ^Uint32;
	lock: Boolean;
	inverse: Byte;
begin
	//Blocage surface
	lock:=SDL_MustLock(surface);
	
	if lock then
		SDL_LockSurface(surface);
	
	//Tableau de pixel
    pixels := surface^.pixels;
    
    //Lecture et conversion du pixel
    pixel_get := TSDL_Color(pixels[(y * surface^.w )+ x]);
    
    //Problème de boutisme
    {$IFDEF ENDIAN_LITTLE}
    inverse:=pixel_get.r;
    pixel_get.r:=pixel_get.b;
    pixel_get.b:=inverse;
    {$ENDIF}
    
    //Déblocage surface
    if lock then
		SDL_UnLockSurface(surface);
end;

function hitBoxInList(c: TSDL_Color; colors: array of TSDL_Color): Boolean;
var i: ShortInt;
begin
	//Initialisation
	i:=0;
	
	//Vérification de présence dans un tableau
	repeat
		hitBoxInList := (colors[i].r=c.r) AND (colors[i].g=c.g) AND (colors[i].b=c.b);
		i:=i+1;
	until (i=Length(colors)) OR (hitBoxInList=True);
end;

procedure hitBoxAddList(var l: T_HITBOX_COLOR; n: ShortInt; c: TSDL_COLOR);
begin
	//Ajout à liste
	setLength(l.data, l.taille+1);
	l.data[l.taille].c:=c;
	l.data[l.taille].n:=n;
	l.taille:=l.taille+1;
end;

function hitBox(surface: PSDL_Surface; p: SDL_Rect; a: Real; colors: array of TSDL_Color): T_HITBOX_COLOR;
var xm, ym, xt, yt: Integer;
	sa,ca: Real;
	i,j,n: ShortInt;
	c : TSDL_Color;
begin
	//Initialisation
	hitBox.taille:=0;
	n:=1; //Point de test
	i:=-1; //coté gauche/droit
	a:= -3.141592/180*a; //Degré vers Radian
	sa:=sin(a); //Optimisation
	ca:=cos(a);
	
	//Point milieu avant
	xm:=p.x+Round(sa*p.h/2);
	ym:=p.y-Round(ca*p.h/2);
	
	//Test point
	c:=pixel_get(surface, xm, ym);
	if hitBoxInList(c, colors) then
		hitBoxAddList(hitBox, n, c);
	
	//Incrémentation point test
	n:=n+1;
	
	while i<>3 do //Gauche -> Droite ( -1 -> 1 )
	begin
		//Point gauche/droite avant
		xt:=xm+i*Round(p.w/2*ca);
		yt:=ym+i*Round(p.w/2*sa);
		
		//Test point
		c:=pixel_get(surface, xt, yt);
		if hitBoxInList(c, colors) then
			hitBoxAddList(hitBox, n, c);
		
		//Incrémentation point
		n:=n+1;
		
		for j:=1 to 4 do //4 points sur chaque coté
		begin
			//Point
			xt:=xt-Round(p.h/4*sa);
			yt:=yt+Round(p.h/4*ca);
			
			//Test point
			c:=pixel_get(surface, xt, yt);
			if hitBoxInList(c, colors) then
				hitBoxAddList(hitBox, n, c);
			
			//Incrémentation point
			n:=n+1;
		end;
		
		//Gauche -> Droite ( -1 -> 1 )
		i:=i+2;
	end;
	
	//Point milieu arrière
	xm:=xm-Round(sa*p.h);
	ym:=ym+Round(ca*p.h);
	
	//Test point
	c:=pixel_get(surface, xm, ym);
	if hitBoxInList(c, colors) then
		hitBoxAddList(hitBox, n, c);
end;

function isSameColor(a,b: TSDL_Color): Boolean;
begin
	//Test couleurs identiques
	isSameColor := (a.r=b.r) AND (a.g=b.g) AND (a.b=b.b);
end;

procedure imageLoad(chemin: String; var surface: PSDL_Surface; alpha: Boolean);
var s: ansiString;
	temp: PSDL_Surface;
begin
	//Conversion vers ansiString ( null-terminated )
	s := chemin;
	//Conversion vers ^char
	temp := IMG_Load(Pchar(s));
	
	//Couche alpha nécessaire (optimisation)
	if alpha then
		// Duplication vers format d'affichage
		surface := SDL_DisplayFormatAlpha(temp)
	else
		// Duplication vers format d'affichage
		surface := SDL_DisplayFormat(temp);
   
	//Libération surface chagée.
	SDL_FreeSurface(temp);
end;

procedure freeUiElement(var element: T_UI_ELEMENT);
var i: Integer;
begin
	//Libération des enfants
	for i:=0 to element.enfants.taille-1 do
		freeUiElement(element.enfants.t[i]^);
	
	//Taille enfants
	element.enfants.taille := 0;

	//Libération surface
	if element.surface <> NIL then
		SDL_FreeSurface(element.surface);

	//Libération police
	if element.typeE = texte then
		TTF_CloseFont(element.police);

	//Libération élément
	if element.valeur <> 'main' then
		FreeMem(@element, SizeOf(T_UI_ELEMENT));
end;


procedure freeInfoPartie(var infoPartie: T_GAMEPLAY);
var i: Integer;
begin
	//Map
	SDL_FreeSurface(infoPartie.map^.surface);

	//Skin joueurs
	for i:=0 to infoPartie.joueurs.taille-1 do
		SDL_FreeSurface(infoPartie.joueurs.t[i].voiture.surface);
	
	//joueurs
	Freemem(infoPartie.joueurs.t, infoPartie.joueurs.taille*SizeOf(T_JOUEUR));

end;

end.
