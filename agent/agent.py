import numpy as np
import time
import random
from collections import deque
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Activation
from tensorflow.keras.optimizers import Adam
from board import customBoard

#ANN
REPLAY_MEMORY_SIZE = 5000 #Nombre transition dans la replay memory
MIN_REPLAY_MEMORY_SIZE = 1000 #nb min de transition avant de commence a .fit()
DISCOUNT = 0.995 #facteur d'actualisation
UPDATE_TARGET_EVERY = 5 #Mise a jour du reseau prédictif tout les X episodes (double estimateur)

#neural net: 3 couches: L1: 16n ; L3: 3/9n; et L1 > L2 > L3
ANN_INPUT = 16
ANN_HIDDEN = 13
ANN_OUTPUT = 9

#SGD
MINIBATCH_SIZE = 16 #Taille d'un batch (fit)
TRAINING_BATCH_SIZE = MINIBATCH_SIZE // 4 #nb echantillon par maj de gradient
LEARNING_RATE = 0.001 



class agent:
	def __init__(self, model_name, restart):
		#Restart training
		self.restart = restart
		
		if(not restart[0]):
			#Creer deux modèles
			self.model = self.create_model()
			self.target_model = self.create_model()

			#Meme Q0
			self.target_model.set_weights(self.model.get_weights())
			
			#LOGS
			self.tensorboard = customBoard(1, log_dir=f"logs/{model_name}-{int(time.time())}")
		else:
			#On restart: charger le modèle
			self.model = tf.keras.models.load_model(restart[1])
			self.target_model = tf.keras.models.load_model(restart[1])
			
			#LOGS
			self.tensorboard = customBoard(restart[2]+1, log_dir=f"logs/{model_name}-{int(time.time())}")
		
		#Replay memory
		self.replay_memory = deque(maxlen=REPLAY_MEMORY_SIZE)
		
		#Compteur maj reseau 2
		self.target_update_counter = 0

		#Init
		self.terminate = False
		self.last_logged_episode = 0
		self.training_initialized = False

	def create_model(self):
		#Creation du model
		model = tf.keras.Sequential()
		
		#Entrée et couche intermediaire
		model.add(Dense(ANN_HIDDEN, input_dim = ANN_INPUT))
		model.add(Activation('relu'))

		model.add(Dense(ANN_HIDDEN))
		model.add(Activation('relu'))
		
		#Sortie: Pas d'activation
		model.add(Dense(ANN_OUTPUT))
		model.add(Activation('linear'))
		
		model.compile(loss = 'mse', optimizer = Adam(lr=LEARNING_RATE), metrics=['accuracy'])

		return model

	def update_replay_memory(self, transition):
		#On ajoute a la replay memory une transition
		# transition = (current_state, action, reward, new_state, done)
		self.replay_memory.append(transition)

	def train(self):
		#On attend d'avoir assez d'element dans la replay memory pour commencer a fit
		if len(self.replay_memory) < MIN_REPLAY_MEMORY_SIZE:
			#print('*NOFIT*******', len(self.replay_memory))
			return
	
		#Un échantillon de la replay memory
		minibatch = random.sample(self.replay_memory, MINIBATCH_SIZE) #[(current_state, action, reward, new_state, done)...]

		#Liste des etat(n)
		current_states = np.array([transition[0] for transition in minibatch])
		
		#Liste des rewards associées aux etats[n] ( Q(s[n]) sur réseau 1 )
		current_qs_list = self.model.predict(current_states, 1)

		#Liste des etat(n+1)
		new_current_states = np.array([transition[3] for transition in minibatch])
		
		#Liste des rewards associées aux etats[n+1] ( Q(s[n+1]) sur réseau 2)
		future_qs_list = self.target_model.predict(new_current_states, 1)

		#Batch a .fit()
		X = []
		y = []

		#On crée le set pour le .fit() : Application formule Q-Learning
		for index, (current_state, action, reward, new_state, done) in enumerate(minibatch):
			if not done:
				#Reward future maximum
				max_future_q = np.max(future_qs_list[index])
				
				#La reward présente doit tenir compte des rewards futures avec facteur d'actualisation
				new_q = reward + DISCOUNT * max_future_q
			else:
				#Si fin, il n'y a pas de reward future
				new_q = reward
				
			#Reward a .fit
			#Anciennes rewards
			current_qs = current_qs_list[index]
			
			#Reward liée a l'action prise, que l'on a calculé
			current_qs[action] = new_q
			
			#On ajoute au batch
			X.append(current_state)
			y.append(current_qs)

		
		#Actions seulement en cas de changement d'episode
		log_this_step = False
		if self.tensorboard.step > self.last_logged_episode:
			self.last_logged_episode = self.tensorboard.step #Maj episode
			log_this_step = True #Log
			self.target_update_counter += 1 #Pour la maj des deux réseau de neurones

		#On fit sur les données en batch
		self.model.fit(np.array(X), np.array(y), batch_size=TRAINING_BATCH_SIZE, verbose=0, shuffle=False, callbacks=[self.tensorboard] if log_this_step else None)
		#print('FIT')
		#On met a jour le model de prédiction
		if self.target_update_counter > UPDATE_TARGET_EVERY:
			self.target_model.set_weights(self.model.get_weights())
			self.target_update_counter = 0

	def get_qs(self, state):
		#Faire une prédiction
		return self.model.predict(np.array(state).reshape(-1, 16))[0]

	def train_in_loop(self):
		#Init le training: Faire un fit au départ car le premier est lent (sauf si on redemarre le training)
		if(not self.restart[0]):
			X = np.random.uniform(size=(1, ANN_INPUT)).astype(np.float32)
			y = np.random.uniform(size=(1, ANN_OUTPUT)).astype(np.float32)
			self.model.fit(np.array(X),np.array(y), verbose=True, batch_size=1)
		
		#Flag
		self.training_initialized = True
		
		#Boucle principale train
		while True:
			if self.terminate:
				return
			self.train()
			time.sleep(0.01)
