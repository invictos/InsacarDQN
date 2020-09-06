import numpy as np
import random
import time
import os
from threading import Thread
import tensorflow as tf
from tqdm import tqdm

from environement import environement
from agent import agent

#Pascal backend
IP = "127.0.0.1"
PORT = 25565

#Episodes
TEMPS_TRAIN_H = 5 #Durée training
S_PER_EPISODE = 10 #Nb max de secondes par episode

EPISODES = round(TEMPS_TRAIN_H*3600/S_PER_EPISODE)

#General
FPS = 22 #FPS des predictions


#Epsilon: Taux d'action prise aléatoirement (exploration)
EPSILON_START = 0.6
MIN_EPSILON = 0.01
MIN_EPSILON_AT = 2/3*EPISODES

EPSILON_DECAY = round(np.exp(np.log(MIN_EPSILON/EPSILON_START)/MIN_EPSILON_AT), 4)


#Logs
AGGREGATE_STATS_EVERY = 10 #On log tout les X episodes
MODEL_NAME = 'AccessViolation' #Nom du modèle
MIN_REWARD = -500 #Reward min avant de log

RESTART = [False, '']
#Debug
def hprint(s):
	print('**********************************'+s+'*********************************')

if __name__ == '__main__':
	# Logs
	ep_rewards = [MIN_REWARD]

	# Init random
	random.seed(1)
	np.random.seed(1)
	tf.random.set_seed(1)

	#Init
	epsilon = EPSILON_START

	# Dossier des modeles
	if not os.path.isdir('models'):
		os.makedirs('models')

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

    
	# Creation de l'agent et de l'environnement
	agent = agent(MODEL_NAME, RESTART)
	env = environement(IP, PORT, S_PER_EPISODE)
	env.startClient()

	
	# On lance le thread de training
	trainer_thread = Thread(target=agent.train_in_loop, daemon=True)
	trainer_thread.start()
	
	#On attend que le thread soit OK
	while not agent.training_initialized:
		time.sleep(0.01)


	#On genere une prediction, car la 1ere est toujours longue
	print(agent.get_qs(np.ones((1, 16))))

	#Boucle principale
	print('**Lancement: ', EPISODES, 'episodes,', EPSILON_DECAY, 'decay,', TEMPS_TRAIN_H, 'heures') 
	
	for episode in tqdm(range(1, EPISODES + 1), ascii=True, unit='episodes'):
		
		# MAJ tensorboard
		agent.tensorboard.step = episode
		
		# reset reward & etape
		episode_reward = 0
		step = 1

		# reset environnement
		current_state = env.reset()
		
		# Init
		done = False
		episode_start = time.time()
		
		#Boucle des etapes
		while True:
			
			#Epsilon
			if np.random.random() > epsilon:
				#Action du modele
				action = np.argmax(agent.get_qs(current_state))
			else:
				#Action aléatoire
				action = np.random.randint(0, 9)
				
				#On attend le meme temps qu'une prédiction
				time.sleep(1/FPS)
			
			#On effectue l'etape
			new_state, reward, done = env.step(action)
			
			#On ajoute l'etape a la replay memory
			agent.update_replay_memory((current_state, action, reward, new_state, done))
			
			#On log les rewards
			episode_reward += reward
			
			#Fin d'etape
			current_state = new_state
			step += 1
			
			#Si on a fini l'etape
			if done:
				break

		#Liste des rewards par episode
		ep_rewards.append(episode_reward)
		
		#Calcul de epsilon
		if epsilon > MIN_EPSILON:
			epsilon *= EPSILON_DECAY
			epsilon = max(MIN_EPSILON, epsilon)
			
		#Log
		if not episode % AGGREGATE_STATS_EVERY or episode == 1:
			#On ne log pas tout les episodes pour ne pas charger le disque
			average_reward = sum(ep_rewards[-AGGREGATE_STATS_EVERY:])/len(ep_rewards[-AGGREGATE_STATS_EVERY:])
			min_reward = min(ep_rewards[-AGGREGATE_STATS_EVERY:])
			max_reward = max(ep_rewards[-AGGREGATE_STATS_EVERY:])
			agent.tensorboard.update_stats(reward_avg=average_reward, reward_min=min_reward, reward_max=max_reward, epsilon=epsilon)
			#print('LOGG STEP')
			
			try:
				#On sauvegarde le modele s'il est correct
				if min_reward > MIN_REWARD:
					print('Model save OK')
					agent.model.save(f'modeles/{MODEL_NAME}__{max_reward:_>7.2f}max_{average_reward:_>7.2f}avg_{min_reward:_>7.2f}min__{int(time.time())}.model')
					
			except (RuntimeError, TypeError, NameError):
				print('Model save NON OK')
				pass
				
	#On a fini les episodes, on termine le thread & attend qu'il retourne
	agent.terminate = True
	trainer_thread.join()
	
	#On sauvegarde le model final
	agent.model.save(f'modeles/{MODEL_NAME}__{max_reward:_>7.2f}max_{average_reward:_>7.2f}avg_{min_reward:_>7.2f}min__{int(time.time())}.model')
