from environement import environement
import time
from tqdm import tqdm
import random
import numpy as np
import tensorflow as tf
import os
import shutil
from collections import deque

#Pascal backend
IP = "127.0.0.1"
PORT = 25565

MODEL_PATH = './modeles/2/'

if __name__ == '__main__':

	#Debug CPU/GPU usage
	#tf.debugging.set_log_device_placement(True)
	
	#Parametres GPU
	gpus = tf.config.experimental.list_physical_devices('GPU')
	if gpus:
		try:
			# Pour avoir 2 tensorflow en meme temps ( tensorboard & model )
			for gpu in gpus:
				tf.config.experimental.set_memory_growth(gpu, True)
				
			#Liste GPU
			logical_gpus = tf.config.experimental.list_logical_devices('GPU')
			print(len(gpus), "Physical GPUs,", len(logical_gpus), "Logical GPUs")
			
		except RuntimeError as e:
			print(e)

    # On charge le model
	model = tf.keras.models.load_model(MODEL_PATH)

	# Démarer l'environnement
	env = environement(IP, PORT, 10000) #10k secondes par episodes
	env.startClient()
	
	# Pour le calcul des FPS, moyenne 60 frames
	fps_counter = deque(maxlen=60)

	#On fait une prédiction avant de commencer, car la première est toujours longue
	model.predict(np.ones((1, 16)))

	#Boucle principale
	while True:
		
		print('Restarting episode')
		
		# Reset environmement
		current_state = env.reset()
		print('reset ok')
		
		
		done = False
		
		# Boucle prédictions
		while True:

			# Pour calcul FPS
			step_start = time.time()

			# On predit une action en fonction de l'etat
			qs = model.predict(np.array(current_state).reshape(-1, 16))[0]
			action = np.argmax(qs)
			
			# On passe l'action a l'environnement, on récupère un etat, la récompense ( & un flag de fin)
			new_state, reward, done = env.step(action)

			# On sauvegarde l'etat
			current_state = new_state

			# Si fin
			if done:
				break

			# Calcul FPS
			frame_time = time.time() - step_start
			fps_counter.append(frame_time)
			
			#Affichage console
			print(f'Agent: {len(fps_counter)/sum(fps_counter):>4.1f} FPS | Action: [{qs[0]:>5.2f}, {qs[1]:>5.2f}, {qs[2]:>5.2f}, {qs[3]:>5.2f}, {qs[4]:>5.2f}, {qs[5]:>5.2f}, {qs[6]:>5.2f}, {qs[7]:>5.2f}, {qs[8]:>5.2f}] {action}')
			# ~ if action == 1:
				# ~ print(f'Agent: {len(fps_counter)/sum(fps_counter):>4.1f} FPS | Action: [{qs[0]:>5.2f}, {qs[1]:>5.2f}, {qs[2]:>5.2f}] {action}')
