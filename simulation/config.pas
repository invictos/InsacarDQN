{*---------------------------------------------------------------------------------------------
 *  Copyright (c) InsaCar. <antoine.camusat@insa-rouen.fr> <anas.katim@insa-rouen.fr>
 *  Licensed under GNU General Public License. See LICENSE in the project root for license information.
 *--------------------------------------------------------------------------------------------*}
unit config;

interface

uses INSACAR_TYPES;
procedure SD_init(var infoPartie: T_GAMEPLAY);

implementation

procedure SD_init(var infoPartie: T_GAMEPLAY);
begin
	/////////////////////////////////
	/////////////////////////////////
	////////////CONFIG///////////////
	/////////////////////////////////
	/////////////////////////////////
	with infoPartie.sd.config do
	begin
		hitPoint := 16; //Nb hitpoint pour etat (16)
		consoleFPS := False; //Affichage FPS dans la console (via clrsrc)
		
		map := True; //Ne pas blit la map, vision voiture (F1)
		render := True; //Stop le rendu, pour training (F2)

		circuit := 2; //Circuit (1-2-3-4)
		frottement := True; //Frottement physique
		safeSpawn := True; //Si faux, mode de spawn training, aléatoire sur circuit 4
		vitesseDepart := 0;
		
		coef.alpha := 200; // Coef braquage, inversement proportionel au rayon de braquage
		coef.avant := 5.6*25*1.1; //Acceleration
		coef.arriere := 5.6*25; //Deceleration
	end;
end;

begin

end.
