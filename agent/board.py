import tensorflow as tf
from tensorflow.keras.callbacks import TensorBoard

class customBoard(TensorBoard): #Do not update tensorboard every .fit()

	# Overriding init to set initial step and writer (we want one log file for all .fit() calls)
	def __init__(self, initStep, **kwargs):
		super().__init__(**kwargs)
		self.step = initStep
		self.writer = tf.summary.create_file_writer(self.log_dir)

	# Overriding this method to stop creating default log writer
	def set_model(self, model):
		pass

	# Overrided, saves logs with our step number
	# (otherwise every .fit() will start writing from 0th step)
	def on_epoch_end(self, epoch, logs=None):
		self.update_stats(**logs)

	# Overrided
	# We train for one batch only, no need to save anything at epoch end
	def on_batch_end(self, batch, logs=None):
		pass
	
	def on_train_batch_end(self, batch, logs=None):
		pass

	# Overrided, so won't close writer
	def on_train_end(self, _):
		pass

	# Custom method for saving own metrics
	# Creates writer, writes custom metrics and closes writer
	def update_stats(self, **stats):
		for stat in stats:
			with self.writer.as_default():
				tf.summary.scalar(stat, stats[stat], step=self.step)

