import os

train_start_bar = 1
train_total_bars = 180

max_encoder_length = 24
max_prediction_length = 6
min_encoder_length = 1

random_seed = 42
learning_rate=1e-3
hidden_size = 40
rnn_layers = 2
dropout = 0.1

batch_size = 64
num_epochs = 50
patience = 5
input_size = 1
output_size = 1

device = "cuda"  # or "cpu"
seed = 42

weight_decay = 1e-5
grad_clip = 0.1

models_path = "models"
images_path = "images"

num_workers = 0

log_interval = 10
log_val_interval = 1
best_model_name = "best_deepar_model"

train_interval_minutes = 60

# ---- storage folders ----

os.makedirs(images_path, exist_ok=True)
os.makedirs(images_path, exist_ok=True)
