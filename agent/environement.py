import numpy as np
import time
import threading
import socket
from collections import deque

NORMALIZE = 500

lock = threading.RLock()
class envClient(threading.Thread): #Loads the client for Pascal Server
	def __init__(self, ip, port):
		threading.Thread.__init__(self)
		self.ip = ip
		self.port = port
		
		#Flag pour decodeur de flux TCP
		self.decode_isSize = True
		self.decode_size = 0
		self.decode_buffer = ''
		
		#AF_INET TCP
		self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		
		#connecter au serveur
		self.sock.connect((self.ip, self.port))
		print('Connected to server on '+self.ip+':'+str(self.port))
		
		#Init variables
		self.ts_start = 0
		self.wallHit = None
		self.envOk = None
		self.dataLast = [0]

	def run(self):
		while True:
			try:
				socketData = self.sock.recv(1024) #On lit 1024 bytes
			except ConnectionResetError:
				print('Erreur ConnectionResetError')
				break;
			
			#On décode le paquet
			packets = self.decodePackets(socketData.decode('ASCII'))
			
			#On decode le(s) messages
			for packet in packets:
				self.processMessage(packet)
				
		#Stop TCP
		self.conn.close()
		print('Connection with server lost.')
		
	def processMessage(self, message):
		#Extraire timestamp, endpoint, payload
		data = message.split('/', 2)

		#Timestamp
		timestamp = int(data[0])

		#EndPoint
		endpoint = int(data[1])
		if(endpoint == 0):
			#Debug
			print('DEBUG: ', [timestamp, endpoint, data[2]])
		elif(endpoint == 1):
			#EnvOK
			print('Process envOk')	
			with lock:
				self.envOk = [timestamp, endpoint, data[2]]
		
		elif(endpoint == 2):
			#Separer data : nbHit, hitsData, speed
			data = data[2].split('/')
			
			#Nombres de marqueurs
			nbHit = int(data[0])
			
			#Données marqueurs
			hitsDecode = data[1].split(';')
			
			#Tableau (int) marqueurs
			hits = np.zeros(nbHit)
			
			#Cast & Normaliser
			for i in range(0, nbHit):
				hits[i] = self.normalize(int(hitsDecode[i]))
			
			#Vitesse
			speed = int(data[2])
			
			#On stocke seulement le dernier etat
			with lock:
				self.dataLast = [timestamp, endpoint, nbHit, hits, speed]
				
		elif((endpoint) == 3 and (self.ts_start < timestamp)):
			#WallHit
			self.hit = np.array(data[2].split(','))
			
			#On stocke seulement le dernier hit
			with lock:
				self.wallHit = [timestamp, endpoint, self.hit[0], self.hit[1]]
	
	def decodePackets(self, stream):
		#Liste de paquets
		packets = []
		
		#On parcours le flux
		for char in stream:
			if char == '$': #Separateur
				if self.decode_isSize: #On a fini de lire la taille
					self.decode_size = int(self.decode_buffer)
					self.decode_isSize = False
					self.decode_buffer = ''
				else:
					if(len(self.decode_buffer) == self.decode_size): #On a fini de lire le message
						packets.append(self.decode_buffer)
					else:
						print('Error DecodePacket size', self.decode_buffer, self.decode_size, self.decode_isSize, stream)
						
					#Reset buffer / flag
					self.decode_isSize = True
					self.decode_buffer = ''
			else:
				self.decode_buffer+=char #On lit un caractère
					
		#Renvoyer les paquets
		return packets
	
	def normalize(self, distance): #On normalise la distance, input entre 0-1
		#Distance max
		if distance < NORMALIZE :
			return round(distance / NORMALIZE , 2)
		else:
			return 1
		
	def sendMessage(self, endpoint, payload):
		#on forme le message
		payload = str(round(time.time()*1000)) + '/' + str(endpoint) + '/' + payload
		
		#On forme le paquet
		packet = str(len(payload))+'$'+payload+'$'
		
		#Envoyer les données
		self.sock.send(bytes(packet, encoding="ASCII")) #Si erreur ICI, verifier (Python > 3) & verifier serveur
 
class environement:
	def __init__(self, ip, port, secPerEp):		
		#Creer serveur
		self.envClient = envClient(ip, port)
		
		#Init
		self.secPerEp = secPerEp
		
	def startClient(self):
		#Lancer serveur
		self.envClient.start()
	
	def encodeAction(self, action):
		#Action 0..8: [g_av,g_ri,g_ar,r_av,r_ri,r_ar,d_av,d_ri,d_ar]
		#ie 6 -> 0,0,1,1,0,0
		#
		#
		#Option de direction (0-2)
		d = action // 3
		
		#Option de vitesse (0-2)
		m = action % 3
		
		#Message de base
		string = '0,0,0,0,0,0'
		
		#On change la bonne option
		string = string[:2*d] + '1' + string[2*d+1:]
		string = string[:6+2*m] + '1' + string[6+2*m+1:]
		
		return string
		
	def customAction(self, action):
		#Definir un mapping custom ( ex: seulement direction)
		return action
		
	def step(self, action):
		#Fonction custom pour les actions des differents models
		action = self.customAction(action)
		
		#Encoder l'action vers un message
		message = self.encodeAction(action) 
		
		#Envoyer le message mouvement
		self.envClient.sendMessage(4, message)
		
		#Lire le dernier etat
		with lock:
			#state
			data = self.envClient.dataLast.copy()
			
			#WallHit
			if (self.envClient.wallHit != None) and (self.envClient.wallHit[0] > self.envClient.ts_start) :
				wallHit = self.envClient.wallHit.copy()
			else:
				wallHit = None
		
		#Calculer la reward
		reward, done = self.reward(data[3], data[4], wallHit)
		
		#On retourne: etat, recompense, fin
		return np.array(data[3]), reward, done
		
	def reward(self, state, speed, wallHit):
		#Fonction de reward
		
		if wallHit != None:
			done = True
			reward = -500
			#print('done wall')
			
		elif speed <= 20:
			done = False
			reward = (-10)+(speed*9/20)
			
		elif speed <= 40:
			done = False
			reward = (-3)+(speed*0.1)
		
		else:
			done = False
			reward = 1
		
		if self.start_time + self.secPerEp < time.time():
			done = True
			#print('done time')
			
		return reward, done
		
	def reset(self):
		#Debug
		t1 = round(time.time()*1000)
		
		#Envoyer le message envReset
		self.envClient.sendMessage(5, 'reset')
		
		#On attend de recevoir envOk
		while True:
			with lock:
				if self.envClient.envOk != None:
					self.envClient.ts_start = self.envClient.envOk[0]
					break
			time.sleep(0.05)
		
		#On attend le premier paquet mouvement
		while True:
			with lock:
				data = self.envClient.dataLast.copy()
				break
		
		#Init
		self.start_time = time.time()
		with lock:
			self.envClient.wallHit = None
			self.envClient.envOk = None
		
		#Debug
		t2 = round(time.time()*1000)
		#print('##EnvOk at', self.envClient.ts_start, 'reset took:', self.envClient.ts_start-t1, '/', t2-t1)
		
		#Retourner le 1er etat
		return np.array(data[3])
