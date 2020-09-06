{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}

program demo;

uses sdl, sdl_ttf, sdl_gfx, INSACAR_TYPES, sysutils, tools, config, crt, selfDriving;

const
	C_UI_FENETRE_NOM = 'InsaCar Alpha 2.0';
	C_REFRESHRATE = 90; //Images par secondes
	C_UI_FENETRE_WIDTH = 1600;//Taille fenêtre
	C_UI_FENETRE_HEIGHT = 900;
	
	//Pour selfDriving: Voir config.pas
	C_PHYSIQUE_FROTTEMENT_COEFFICIENT_AIR = 0.2; // kg.s^(-1)
	
	C_PHYSIQUE_VOITURE_ACCELERATION_AVANT = 5.6; // m.s^(-2)
	C_PHYSIQUE_VOITURE_ACCELERATION_ARRIERE = 3;// m.s^(-2)
	C_PHYSIQUE_VOITURE_ACCELERATION_FREIN = 12;// m.s^(-2)
	C_PHYSIQUE_VOITURE_ANGLE = 90; // Deg.s^(-1)

procedure frame_afficher_low(var element: T_UI_ELEMENT; var frame: PSDL_Surface; etat: T_RENDER_ETAT);
var i : Integer;
		s : ansiString;
begin
	case element.typeE of
		couleur:
		begin
			//Rendu couleur
			SDL_FillRect(element.surface, NIL, SDL_MapRGBA(element.surface^.format, element.couleur.r, element.couleur.g, element.couleur.b, 255));
		end;
		
		texte:
		begin
			//Suppression ancien texte
			SDL_FreeSurface(element.surface);
			//Convertion ansiString (null-terminated)
			s:= element.valeur;
			//Rendu Texte
			element.surface := TTF_RenderText_Blended(element.police, Pchar(s), element.couleur);
		end;
	end;

	//Application des styles
	if element.style.enabled then
	begin
		//Transparence
		if element.style.a<>255 then
			SDL_SetAlpha(element.surface, SDL_SRCALPHA, element.style.a);
	end;

	//Calcul position
	etat.rect.x:=etat.rect.x+element.etat.x;
	etat.rect.y:=etat.rect.y+element.etat.y;

	//Rendu SDL
	if element.style.blit then
		SDL_BlitSurface(element.surface, NIL, frame, @etat.rect);
	
	//PostRendu (curseur)
	if (element.typeE = texte) AND (element.enfants.taille <> 0) AND (element.surface <> NIL) then
		etat.rect.x:=etat.rect.x + element.surface^.w;
	
	//Rendu enfants
	for i:=0 to element.enfants.taille-1 do
		//Test affichage
		if element.enfants.t[i]^.style.display then
			frame_afficher_low(element.enfants.t[i]^, frame, etat);
end;

procedure frame_afficher(var element: T_UI_ELEMENT);
var etat: T_RENDER_ETAT;
begin
	//Initialisation
	etat.rect.x:=0;
	etat.rect.y:=0;
	etat.a:=255;
	
	//Lancement fonction récursive
	frame_afficher_low(element,element.surface,etat);
end;

procedure afficher_hud(var infoPartie: T_GAMEPLAY);
begin
	//Temps géneral
	infoPartie.hud.temps^.valeur:= concat('Temps : ', seconde_to_temps(infoPartie.temps.last-infoPartie.temps.debut));
	
	//Tour
	infoPartie.hud.actuelTour^.valeur := concat('Tour : ', intToStr(infoPartie.joueurs.t[0].nbTour));

	//Affichage vitesse
	infoPartie.joueurs.t[0].hud.vitesse^.valeur:=Concat(IntToStr(Round(-infoPartie.joueurs.t[0].voiture.physique^.dr/2.5)),' km/h');
	
	//Affichage temps secteurs
	if infoPartie.joueurs.t[0].temps.actuel <> 0 then
		infoPartie.joueurs.t[0].hud.secteur[infoPartie.joueurs.t[0].temps.actuel-1]^.valeur := concat('S',intToStr(infoPartie.joueurs.t[0].temps.actuel), ' : ',seconde_to_temps(infoPartie.temps.last-infoPartie.joueurs.t[0].temps.secteur[infoPartie.joueurs.t[0].temps.actuel-1]));
end;

procedure afficher_camera(var infoPartie: T_GAMEPLAY; var fenetre: T_UI_ELEMENT);
var centre: array[0..1] of Real;
begin
	//Calcul centre par rapport au J1
	centre[0] := infoPartie.joueurs.t[0].voiture.physique^.x;
	centre[1] := infoPartie.joueurs.t[0].voiture.physique^.y;
	
	//Placement carte
	fenetre.enfants.t[0]^.etat.x := -Round(centre[0]-C_UI_FENETRE_WIDTH/2);
	fenetre.enfants.t[0]^.etat.y := -Round(centre[1]-C_UI_FENETRE_HEIGHT/2);
	
	//Voiture Joueur
	//Libération surface
	SDL_FreeSurface(infoPartie.joueurs.t[0].voiture.ui^.surface);
		
	//Nouvelle surface
	infoPartie.joueurs.t[0].voiture.ui^.surface := rotozoomSurface(infoPartie.joueurs.t[0].voiture.surface, infoPartie.joueurs.t[0].voiture.physique^.a, 1, 1);
	
	//Placement joueur
	infoPartie.joueurs.t[0].voiture.ui^.etat.x := Round(infoPartie.joueurs.t[0].voiture.physique^.x+fenetre.enfants.t[0]^.etat.x-infoPartie.joueurs.t[0].voiture.ui^.surface^.w/2);
	infoPartie.joueurs.t[0].voiture.ui^.etat.y := Round(infoPartie.joueurs.t[0].voiture.physique^.y+fenetre.enfants.t[0]^.etat.y-infoPartie.joueurs.t[0].voiture.ui^.surface^.h/2);
end;

procedure course_afficher(var infoPartie: T_GAMEPLAY; var fenetre: T_UI_ELEMENT);
begin
	//Affichage caméra (circuit+voitures)
	afficher_camera(infoPartie, fenetre);
	
	//Affichage HUD (Informations)
	afficher_hud(infoPartie);
end;

procedure frame_physique(var physique: T_PHYSIQUE_TABLEAU; var infoPartie: T_GAMEPLAY);
var	c: array of TSDL_Color;
	p : SDL_Rect;
	
begin
	//Initialisation couleurs
	setLength(c,1);
	c[0].r:=57;
	c[0].g:=181;
	c[0].b:=74;
	
	//Coordonnées joueur
	p.x := Round(infoPartie.joueurs.t[0].voiture.physique^.x);
	p.y := Round(infoPartie.joueurs.t[0].voiture.physique^.y);
	
	//La voiture a touché un mur (pixel vert)
	if(Uint32(c[0]) = Uint32(pixel_get(infoPartie.map^.surface, p.x, p.y))) then
	begin
		infoPartie.joueurs.t[0].voiture.physique^.dr := 0; //Vitesse a 0
		SD_message(3, concat(intToStr(p.x), ',', intToStr(p.y)), infoPartie); //Message environnement
	end;
	
	if infoPartie.sd.config.frottement then //Frottement: { dr(n+1) = dr(n) - dt*AccFrein } ici accFrein=dr*CoefFrottement
		infoPartie.joueurs.t[0].voiture.physique^.dr:=infoPartie.joueurs.t[0].voiture.physique^.dr - infoPartie.temps.dt*C_PHYSIQUE_FROTTEMENT_COEFFICIENT_AIR*infoPartie.joueurs.t[0].voiture.physique^.dr;
	
	//Calcul positions { x(n+1) = x(n) + dt*sin(a)*dr }
	infoPartie.joueurs.t[0].voiture.physique^.x:=infoPartie.joueurs.t[0].voiture.physique^.x + infoPartie.temps.dt*sin(3.141592/180*infoPartie.joueurs.t[0].voiture.physique^.a)*infoPartie.joueurs.t[0].voiture.physique^.dr;
	infoPartie.joueurs.t[0].voiture.physique^.y:=infoPartie.joueurs.t[0].voiture.physique^.y + infoPartie.temps.dt*cos(3.141592/180*infoPartie.joueurs.t[0].voiture.physique^.a)*infoPartie.joueurs.t[0].voiture.physique^.dr;

end;

procedure course_user(var infoPartie: T_GAMEPLAY);
var event_sdl: TSDL_Event;
	event_clavier: PUint8;
begin
	//Vérification fermeture fenêtre
	while(SDL_PollEvent(@event_sdl) <> 0) do
		case event_sdl.type_ of
			SDL_QUITEV: //Quitter si clic sur la croix rouge
				begin
					infoPartie.actif:=False;
					writeln('QUITTER CROIX');
				end;
			SDL_KEYDOWN:
				case event_sdl.key.keysym.sym of
					SDLK_H: //Quitter si touche H
						begin
							infoPartie.actif := False;
							writeln('QUITTER H');
						end;
					else
						SD_input_handler(infoPartie, event_sdl.key.keysym.sym); //Event handler pour les touches Fn SelfDriving
				end;
		end;

	//Etat clavier pour touches deplacement (répétition)
	event_clavier := SDL_GetKeyState(NIL);
	
	//Avant ou frein (si Marche arriere)
	{$IFDEF WINDOWS} //Bug azerty->querty windows
	if event_clavier[SDLK_Q] = SDL_PRESSED then
	{$ENDIF}
	{$IFDEF LINUX}
	if event_clavier[SDLK_A] = SDL_PRESSED then	
	{$ENDIF}
		if infoPartie.joueurs.t[0].voiture.physique^.dr < 0 then 
			infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr - infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ACCELERATION_AVANT*25
		else
			infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr - infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ACCELERATION_FREIN*25;
	
	//Frein ou marche arrière
	if event_clavier[SDLK_TAB] = SDL_PRESSED then
		if infoPartie.joueurs.t[0].voiture.physique^.dr < 0 then 
			infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr + infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ACCELERATION_FREIN*25
		else
			infoPartie.joueurs.t[0].voiture.physique^.dr := infoPartie.joueurs.t[0].voiture.physique^.dr + infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ACCELERATION_ARRIERE*25;
	
	//Gauche
	if event_clavier[SDLK_R] = SDL_PRESSED then
		infoPartie.joueurs.t[0].voiture.physique^.a := infoPartie.joueurs.t[0].voiture.physique^.a + infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ANGLE;
	
	//Droite
	if event_clavier[SDLK_Y] = SDL_PRESSED then
		infoPartie.joueurs.t[0].voiture.physique^.a := infoPartie.joueurs.t[0].voiture.physique^.a - infoPartie.temps.dt*C_PHYSIQUE_VOITURE_ANGLE;

end;

procedure partie_course(var infoPartie: T_GAMEPLAY; var physique: T_PHYSIQUE_TABLEAU; var fenetre: T_UI_ELEMENT);{Main Loop}
var	timer: array[0..7] of LongInt; {départ, boucle, delay,user,physique,gameplay,courseAfficher,frameAfficher}
	x,y: tcrtcoord;
begin
	
	//Démarage temps
	infoPartie.temps.debut := SDL_GetTicks();
	infoPartie.temps.last := infoPartie.temps.debut;
	
	//Boucle de jeu
	infoPartie.actif:=True;
	
	while infoPartie.actif do
	begin
		if C_DEBUG then
			clrScr();
		
		SD_debug('e0');
		//Calcul dt pour interpolation
		infoPartie.temps.dt := (SDL_GetTicks()-infoPartie.temps.last)/1000;
		
		//Nouveau temps
		infoPartie.temps.last := SDL_GetTicks();
		SD_debug('e1');
		
		//Intéraction utilisateur
		course_user(infoPartie);
		SD_debug('e2');
		
		//Mouvements physique
		frame_physique(physique, infoPartie);
		SD_debug('e3');
		
		////////////////////
		////////////////////
		///////NETWORK//////
		////////////////////
		////////////////////
		if infoPartie.actif then //Gameplay peut stop la partie
			SD_network(infoPartie, fenetre);
		
		SD_debug('e4');
		
		//Affichage (genere le plan de l'image)
		course_afficher(infoPartie, fenetre);
		SD_debug('e5');
		
		if(infoPartie.sd.config.render) then
		begin
			//Affichage ou non de la map
			infoPartie.map^.style.blit := infoPartie.sd.config.map;
			
			//Rendu
			frame_afficher(fenetre);
			SD_debug('e6');
			
			//Mise a jour écran
			SDL_Flip(fenetre.surface);
		end;
		
		SD_debug('e7');
		
		//Calcul temps éxecution
		timer[0] := SDL_GetTicks() - infoPartie.temps.last;

		//Calcul délai
		timer[1] := Round(1000/C_REFRESHRATE)-timer[0];
		if timer[1] < 0 then
			timer[1]:=0;
		
		//Affichage console
		if infoPartie.sd.config.consoleFPS then
		begin
			x:= WhereX();
			y:= WhereY();
			gotoxy(1,1);
			writeln('|||||',C_UI_FENETRE_NOM,'|||||');
			write('Took ',timer[0], 'ms to render. FPS=');
			ClrEol();
			write(1000 div timer[0]);
			gotoxy(x,y);
		end;
		SD_debug('e8');
		
		//Délai
		SDL_Delay(timer[1]);
		
		SD_debug('e9');
	end;
end;

procedure partie_init(var infoPartie: T_GAMEPLAY; var physique: T_PHYSIQUE_TABLEAU; var fenetre: T_UI_ELEMENT);
var j: Integer;
	panneau: P_UI_ELEMENT;
begin
	
	//Initialisation
	infoPartie.temps.debut:=0;
	infoPartie.temps.last:=0;
	infoPartie.temps.dt:=0;
	fenetre.enfants.taille:=0;
	physique.taille:=0;

	//Couleur fond
	fenetre.typeE:=couleur;
	fenetre.couleur.r:=57;
	fenetre.couleur.g:=181;
	fenetre.couleur.b:=74;
	fenetre.style.a:=255;
	
	//Config init
	SD_Init(infoPartie);
	
	//Charger map
	ajouter_enfant(fenetre);
	infoPartie.map := fenetre.enfants.t[fenetre.enfants.taille-1];
	imageLoad(concat('./res/c', intToStr(infoPartie.sd.config.circuit), '.png'), infoPartie.map^.surface, false);
	fenetre.enfants.t[fenetre.enfants.taille-1]^.typeE := image;
	fenetre.enfants.t[fenetre.enfants.taille-1]^.style.enabled:=False; //Desactive masque alpha
	
	//Chargement T_JOUEUR
	infoPartie.joueurs.taille := 1;
	GetMem(infoPartie.joueurs.t, infoPartie.joueurs.taille*SizeOf(T_JOUEUR));
	
	//Création joueur
	//Initialisation
	for j:=1 to 3 do
		infoPartie.joueurs.t[0].temps.tours[j]:=0;
		
	for j:=0 to 4 do
		infoPartie.joueurs.t[0].temps.secteur[j]:=0;
	
	infoPartie.joueurs.t[0].temps.actuel := 0;
	infoPartie.joueurs.t[0].nbTour := 1;
	
	//Informations
	infoPartie.joueurs.t[0].voiture.chemin := './res/V0.png';
	infoPartie.joueurs.t[0].nom := 'DrivingBot';
	
	//Ajout UI
	ajouter_enfant(fenetre);
	infoPartie.joueurs.t[0].voiture.ui := fenetre.enfants.t[fenetre.enfants.taille-1];
	infoPartie.joueurs.t[0].voiture.ui^.surface := NIL;
	infoPartie.joueurs.t[0].voiture.ui^.typeE := image;
	imageLoad(infoPartie.joueurs.t[0].voiture.chemin, infoPartie.joueurs.t[0].voiture.surface, True);
	
	//Ajout physique
	ajouter_physique(physique);
	infoPartie.joueurs.t[0].voiture.physique := physique.t[physique.taille-1];
   
   
	SD_setPositionStart(infoPartie.sd.config.circuit, infoPartie.joueurs.t[0].voiture.physique);

	//Masque HUD
	ajouter_enfant(fenetre);
	infoPartie.hud.global := fenetre.enfants.t[fenetre.enfants.taille-1];
	infoPartie.hud.global^.typeE := couleur;
	infoPartie.hud.global^.style.a :=0;
	infoPartie.hud.global^.etat.w:=1600;
	infoPartie.hud.global^.etat.h:=900;
	infoPartie.hud.global^.surface:= SDL_CreateRGBSurface(0, fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.w, fenetre.enfants.t[fenetre.enfants.taille-1]^.etat.h, 32, 0,0,0,0);
	
		//HUD Fond HautDroite (Temps)
		ajouter_enfant(infoPartie.hud.global^);
		panneau := infoPartie.hud.global^.enfants.t[infoPartie.hud.global^.enfants.taille-1];
		panneau^.typeE := couleur;
		panneau^.style.a :=128;
		panneau^.etat.w:=300;
		panneau^.etat.h:=90;
		panneau^.etat.x:=1300;
		panneau^.surface:= SDL_CreateRGBSurface(0,panneau^.etat.w,panneau^.etat.h, 32, 0,0,0,0);

			//HUD Circuit nom
			ajouter_enfant(panneau^);										
			panneau^.enfants.t[panneau^.enfants.taille-1]^.typeE := texte;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.valeur := Concat('Circuit : ',intToStr(infoPartie.sd.config.circuit));
			panneau^.enfants.t[panneau^.enfants.taille-1]^.police := TTF_OpenFont('./res/arial.ttf',25);
			panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.x:=5;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.y:=10;
			
			//HUD Temps
			ajouter_enfant(panneau^);
			infoPartie.hud.temps := panneau^.enfants.t[panneau^.enfants.taille-1];
			infoPartie.hud.temps^.typeE := texte;
			infoPartie.hud.temps^.valeur := 'Temps : ';
			infoPartie.hud.temps^.police := TTF_OpenFont('./res/arial.ttf',25);
			infoPartie.hud.temps^.etat.x:=5;
			infoPartie.hud.temps^.etat.y:=50;
		
		//HUD Fond HautGauche (nb Tour)
		ajouter_enfant(infoPartie.hud.global^);
		panneau := infoPartie.hud.global^.enfants.t[infoPartie.hud.global^.enfants.taille-1];
		panneau^.typeE := couleur;
		panneau^.style.a :=128;
		panneau^.etat.w:=250;
		panneau^.etat.h:=50;
		panneau^.surface:= SDL_CreateRGBSurface(0, panneau^.etat.w, panneau^.etat.h, 32, 0,0,0,0);
			
		//HUD texte 'Tour'
		ajouter_enfant(panneau^);
		infoPartie.hud.actuelTour := panneau^.enfants.t[panneau^.enfants.taille-1];
		panneau^.enfants.t[panneau^.enfants.taille-1]^.typeE := texte;
		panneau^.enfants.t[panneau^.enfants.taille-1]^.valeur := 'Tour : ';
		panneau^.enfants.t[panneau^.enfants.taille-1]^.police := TTF_OpenFont('./res/arial.ttf',25);
		panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.r :=235;
		panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.g :=130;
		panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.b :=24;
		panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.x:=5;
		panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.y:=10;
	

		//HUD fond joueur
		ajouter_enfant(infoPartie.hud.global^);
		panneau :=infoPartie.hud.global^.enfants.t[infoPartie.hud.global^.enfants.taille-1];
		panneau^.typeE := couleur;
		panneau^.style.a :=128;
		panneau^.etat.w:=200;
		panneau^.etat.h:=200; 
		panneau^.etat.x:=1400;
		panneau^.etat.y:=700;
		panneau^.surface:= SDL_CreateRGBSurface(0, panneau^.etat.w, panneau^.etat.h, 32, 0,0,0,0);
			
			//HUD pseudo joueur
			ajouter_enfant(panneau^);
			panneau^.enfants.t[panneau^.enfants.taille-1]^.typeE := texte;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.valeur := Concat('J1 : ',infoPartie.joueurs.t[0].nom);
			panneau^.enfants.t[panneau^.enfants.taille-1]^.police := TTF_OpenFont('./res/arial.ttf',25);
			panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.r :=235;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.g :=130;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.couleur.b :=24;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.x:=5;
			panneau^.enfants.t[panneau^.enfants.taille-1]^.etat.y:=5;

			//HUD vitesse joueur
			ajouter_enfant(panneau^);
			infoPartie.joueurs.t[0].hud.vitesse:=panneau^.enfants.t[panneau^.enfants.taille-1];
			infoPartie.joueurs.t[0].hud.vitesse^.typeE := texte;
			infoPartie.joueurs.t[0].hud.vitesse^.valeur := 'Vitesse';
			infoPartie.joueurs.t[0].hud.vitesse^.police := TTF_OpenFont('./res/arial.ttf',25);
			infoPartie.joueurs.t[0].hud.vitesse^.etat.x := 5;
			infoPartie.joueurs.t[0].hud.vitesse^.etat.y := 40;
			
			//HUD temps secteurs
			for j:=0 to 2 do
			begin
				ajouter_enfant(panneau^);
				infoPartie.joueurs.t[0].hud.secteur[j] := panneau^.enfants.t[panneau^.enfants.taille-1];
				infoPartie.joueurs.t[0].hud.secteur[j]^.typeE := texte;
				infoPartie.joueurs.t[0].hud.secteur[j]^.police := TTF_OpenFont('./res/arial.ttf',25);
				infoPartie.joueurs.t[0].hud.secteur[j]^.etat.x := 5;
				infoPartie.joueurs.t[0].hud.secteur[j]^.etat.y := 90+30*j;
			end;
		
			
		/////////////////
		/////////////////
		/////NETWORK/////
		/////////////////
		/////////////////
		SD_Load(infoPartie, fenetre);
end;

procedure jeu_partie(fenetre: T_UI_ELEMENT);
var physique : T_PHYSIQUE_TABLEAU;
	infoPartie: T_GAMEPLAY;
begin	
	//Initialisation
	partie_init(infoPartie, physique, fenetre);
	
	//Partie
	partie_course(infoPartie, physique, fenetre);
	
	//Libération surface
	freeUiElement(fenetre);
	
	//Libération infoPartie
	freeInfoPartie(infoPartie);
end;

function lancement(): T_UI_ELEMENT;
begin
	//Affichage console
	writeln('|||', C_UI_FENETRE_NOM, '|||');
	writeln('#Lancement...');
	
	//Initialisation librairie SDL
	if SDL_Init(SDL_INIT_TIMER or SDL_INIT_VIDEO) = 0 then
	begin
		//Initialisation librairie TTF
		TTF_Init();
		
		//Création fenetre SDL & surface
		lancement.surface := SDL_SetVideoMode(C_UI_FENETRE_WIDTH, C_UI_FENETRE_HEIGHT, 32, SDL_HWSURFACE or SDL_DOUBLEBUF);
		
		//Validation surface
		if lancement.surface <> NIL then
		begin
			//Titre fenêtre
			SDL_WM_SetCaption(C_UI_FENETRE_NOM, NIL);
			
			//Initialisation
			lancement.etat.x:=0;
			lancement.etat.y:=0;
			lancement.valeur:='main';
			lancement.enfants.t:=NIL;
			lancement.enfants.taille:=0;
			lancement.parent:=NIL;
		end else
			//Erreur création fenêtre
			writeln('Erreur setVideoMode');
	end	else
		//Erreur initialisation SDL
		writeln('Erreur Initialisation');
end;

var fenetre : T_UI_ELEMENT;
begin
	//Initialisation
	fenetre := lancement();

	//Lancement Partie
	jeu_partie(fenetre);
	
	//Libération mémoire
	freeUiElement(fenetre);
	
	//Déchargement librairie TTF
	TTF_Quit();
	
	//Déchargement librairie SDL
	SDL_Quit();
end.
