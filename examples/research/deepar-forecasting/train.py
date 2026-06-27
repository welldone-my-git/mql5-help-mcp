import torch
import lightning.pytorch as pl
import matplotlib.pyplot as plt
import pytorch_forecasting
from pytorch_forecasting import DeepAR, TimeSeriesDataSet
from lightning.pytorch.callbacks import EarlyStopping, ModelCheckpoint
from pytorch_forecasting.metrics import MultivariateNormalDistributionLoss
from pytorch_forecasting import DeepAR
# from lightning.pytorch.tuner import Tuner
import os
import config
import warnings

warnings.filterwarnings("ignore")
torch.serialization.add_safe_globals([pytorch_forecasting.data.encoders.GroupNormalizer])
torch.serialization.safe_globals([pytorch_forecasting.data.encoders.GroupNormalizer])

pl.seed_everything(config.random_seed) # set random seed for the lightning module

def run(training: TimeSeriesDataSet,
        train_dataloader: any,
        val_dataloader: any, 
        loss: pytorch_forecasting.metrics = MultivariateNormalDistributionLoss(rank=30),
        best_model_name: str=config.best_model_name) -> DeepAR:
    
    # model's checkpoint
    
    checkpoint_callback = ModelCheckpoint(
        dirpath=config.models_path,
        filename=best_model_name,
        save_top_k=1,
        mode="min",
        monitor="val_loss"
    )

    # create trainer

    trainer = pl.Trainer(
        max_epochs=config.num_epochs,
        accelerator="gpu" if torch.cuda.is_available() else "cpu",
        gradient_clip_val=config.grad_clip,
        callbacks=[EarlyStopping(monitor="val_loss", patience=config.patience, mode="min"), checkpoint_callback],
        logger=False,
    )    

    # create DeepAR model
        
    model = DeepAR.from_dataset(
        training,
        learning_rate=config.learning_rate,
        hidden_size=config.hidden_size,
        rnn_layers=config.rnn_layers,
        dropout=config.dropout,

        # --- probabilistic forecasting ---
        loss=loss,

        log_interval=config.log_interval,
        log_val_interval=config.log_val_interval,
    )
    
    res = None
    try:
        # find the optimal learning rate
        
        """
        res = Tuner(trainer).lr_find(
            model, train_dataloaders=train_dataloader, val_dataloaders=val_dataloader, early_stop_threshold=1000.0, max_lr=0.3,
        )
            
        # and plot the result - always visually confirm that the suggested learning rate makes sense
        print(f"suggested learning rate: {res.suggestion()}")
        fig = res.plot(show=True, suggest=True)
        fig.savefig(os.path.join(config.images_path, "lr_finder.png"))
        """
        
        # fit the model

        trainer.fit(
            model,
            train_dataloaders=train_dataloader,
            val_dataloaders=val_dataloader,
        )

    except Exception as e:
        raise RuntimeError(e)

    best_model_path = checkpoint_callback.best_model_path
    best_model = DeepAR.load_from_checkpoint(best_model_path, weights_only=False)

    # make probabilistic forecasts

    raw_predictions = best_model.predict(val_dataloader, mode="raw", return_x=True)

    # plot predictions 
    
    # for idx in range(config.max_prediction_length):
    for idx in range(len(raw_predictions.x["decoder_time_idx"])):
        
        best_model.plot_prediction(
            raw_predictions.x,
            raw_predictions.output,
            idx=idx,
            add_loss_to_title=True
        )   

        plt.savefig(os.path.join(config.images_path, "deepar_forecast_{}.png".format(idx+1)))
        # plt.show()

    return model
    