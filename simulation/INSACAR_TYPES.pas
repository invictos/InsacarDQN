{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}

unit INSACAR_TYPES;

interface
uses sdl, sdl_ttf, selfDrivingThread, syncobjs;

type

	T_RENDER_ETAT = record
		rect: TSDL_Rect;
		a: Byte;
	end;
	
	T_RENDER_STYLE = record
		enabled, display, blit: Boolean;
		a : Byte;
	end;
	
	T_HITBOX_COLOR = record
		data : array of record
			n: shortint;
			c: TSDL_Color;
		end;
		taille: shortInt;
	end;
	
	T_PHYSIQUE_TABLEAU = record
		t: ^P_PHYSIQUE_ELEMENT;
		taille: Integer;
	end;
	
	T_PHYSIQUE_ELEMENT = record
		x,y: Real;
		a,r,dr: Real;
	end;
	P_PHYSIQUE_ELEMENT = ^T_PHYSIQUE_ELEMENT;
	
	T_UI_TABLEAU = record
		t: ^P_UI_ELEMENT;
		taille: Integer;
	end;
	
	T_UI_ELEMENT = record
		etat: SDL_RECT; {dimension / position}
		surface: PSDL_SURFACE;
		typeE:(null, image, texte, couleur);
		valeur : String;
		couleur: TSDL_COLOR;
		style: T_RENDER_STYLE;
		police: PTTF_Font;
		enfants: T_UI_TABLEAU;
		parent: ^T_UI_ELEMENT;
	end;
	P_UI_ELEMENT = ^T_UI_ELEMENT;
	
	T_SELFDRIVING = record
		server: T_ThreadServer;
		lock : TCriticalSection;
		config: record
			map, render, frottement, consoleFPS, safeSpawn: boolean;
			hitPoint, vitesseDepart, circuit: Integer;
			coef: record
				alpha, avant, arriere: Real;
			end;
		end;
		marqueurs : ^P_UI_ELEMENT;
	end;
	
	T_GAMEPLAY = record
		temps: record
			debut: LongInt;
			last: LongInt;
			dt: Double;
		end;
		map: P_UI_ELEMENT;
		hud: record	
            temps : P_UI_ELEMENT;
            global : P_UI_ELEMENT;
            actuelTour : P_UI_ELEMENT;
            nom_premier : P_UI_ELEMENT;
        end;
		joueurs : record
			t: ^T_JOUEUR; //PARTIE
			taille: Integer;
		end;
		actif : boolean;
		sd : T_SELFDRIVING;
	end;
	
	T_JOUEUR = record
		voiture: record
			chemin: String;
			surface: PSDL_SURFACE;
			current: ^PSDL_Surface;
			physique: P_PHYSIQUE_ELEMENT;
			ui: P_UI_ELEMENT;
		end;
		hud : record 
			vitesse : P_UI_ELEMENT;
			secteur: array[0..2] of P_UI_ELEMENT;
		end;
		temps : record
			secteur: array[0..3] of LongInt;
			tours: array[1..3] of LongInt;
			actuel: ShortInt;
		end;
		nbTour: Integer;
		nom: String;
	end;
	
implementation
begin
end.
