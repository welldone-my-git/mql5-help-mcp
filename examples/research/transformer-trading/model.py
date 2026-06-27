import warnings
warnings.filterwarnings("ignore")

from torch.utils.data import DataLoader
from ast import Load
from pytorch_forecasting import TemporalFusionTransformer, TimeSeriesDataSet
from pytorch_forecasting.data import GroupNormalizer
import pytorch_forecasting.metrics as metrics
from pytorch_forecasting.models.temporal_fusion_transformer.tuning import (
    optimize_hyperparameters,
)

import lightning.pytorch as pl
from lightning.pytorch.callbacks import EarlyStopping, LearningRateMonitor
from lightning.pytorch.loggers import TensorBoardLogger
from pytorch_forecasting.tuning import Tuner
import os
import pickle
from typing import Optional
import matplotlib.pyplot as plt

class TFTModel:
    def __init__(self, training: TimeSeriesDataSet, 
                train_dataloader: DataLoader, 
                val_dataloader: DataLoader,
                parameters: dict,
                loss: metrics=metrics.QuantileLoss(),
                trainer_max_epochs = 10):
        
        """
        Initialize the Temporal Fusion Transformer model with training and validation data.
        Args:
            training (TimeSeriesDataSet): The training dataset loader containing time series data
                for model training.
            parameters (dict): A dictionary containing hyperparameters for the model configuration:
                - learning_rate (float, optional): Learning rate for the optimizer. Default is 0.03.
                - hidden_size (int, optional): Size of hidden layers. Most important hyperparameter apart
                  from learning rate. Default is 8.
                - attention_head_size (int, optional): Number of attention heads. Set to up to 4 for
                  large datasets. Default is 2.
                - dropout (float, optional): Dropout rate for regularization. Values between 0.1 and 0.3
                  are recommended. Default is 0.1.
                - hidden_continuous_size (int, optional): Size of continuous hidden layers. Should be set
                  to <= hidden_size. Default is 8.
            loss (metrics): Loss function to be used for model training, e.g., QuantileLoss.
        Attributes:
            model (TemporalFusionTransformer): The initialized Temporal Fusion Transformer model with
                a given loss function and Ranger optimizer.
            trainer: PyTorch Lightning trainer instance configured for model training.
        """

        # configure network and trainer
        pl.seed_everything(42)

        self.train_dataloader = train_dataloader
        self.val_dataloader = val_dataloader
        self.training = training
        self.loss = loss
        
        self.model = self._create_model(parameters=parameters)
        self.trainer = self._create_trainer(max_epochs=trainer_max_epochs)

    def _create_model(self, parameters: dict) -> TemporalFusionTransformer:

        return TemporalFusionTransformer.from_dataset(
            self.training,
            # not meaningful for finding the learning rate but otherwise very important
            learning_rate=parameters.get("learning_rate", 0.03),
            hidden_size=parameters.get("hidden_size", 8),  # most important hyperparameter apart from learning rate
            # number of attention heads. Set to up to 4 for large datasets
            attention_head_size=parameters.get("attention_head_size", 2),
            dropout=parameters.get("dropout", 0.1),  # between 0.1 and 0.3 are good values
            hidden_continuous_size=parameters.get("hidden_continuous_size", 8),  # set to <= hidden_size
            loss=self.loss,
            optimizer="ranger",
            # reduce learning rate if no improvement in validation loss after x epochs
            # reduce_on_plateau_patience=1000,
        )
        
    def _create_trainer(self, max_epochs: int=50, grad_clip_val=0.1, limit_train_batches: int=50) -> pl.Trainer:
        
        lr_logger = LearningRateMonitor()  # log the learning rate
        logger = TensorBoardLogger("lightning_logs")  # logging results to a tensorboard

        # configure network and trainer
        early_stop_callback = EarlyStopping(
            monitor="val_loss", min_delta=1e-4, patience=10, verbose=False, mode="min"
        )

        return pl.Trainer(
            max_epochs=max_epochs,
            accelerator="cpu",
            enable_model_summary=True,
            gradient_clip_val=grad_clip_val,
            limit_train_batches=limit_train_batches,  # comment in for training, running validation every 30 batches
            # fast_dev_run=True,  # comment in to check that networkor dataset has no serious bugs
            callbacks=[lr_logger, early_stop_callback],
            logger=logger,
        )


    def find_optimal_lr(self, plot_output_dir: str,
                        max_lr: float=10.0,
                        min_lr: float=1e-6,
                        show_plot: bool=False,
                        save_plot: bool=True) -> float:
        
        """find an optimal learning rate"""
        
        res = Tuner(self.trainer).lr_find(
            self.model,
            train_dataloaders=self.train_dataloader,
            val_dataloaders=self.val_dataloader,
            max_lr=max_lr,
            min_lr=min_lr,
        )

        optimal_lr = res.suggestion()
        
        # ---- optional, saving the plot ---- 
        
        fig = res.plot(show=show_plot, suggest=True)
        
        if save_plot:
            try:
                fig.savefig(os.path.join(plot_output_dir, "lr_finder.png"))
            except Exception as e:
                print("Error saving learning rate finder plot: ", e)
        
        return optimal_lr
    
    def load_best_model(self) -> bool:
        
        """Load the best model checkpoint after training."""
        
        model = None
        
        try:
            best_model_path = self.trainer.checkpoint_callback.best_model_path
            model = TemporalFusionTransformer.load_from_checkpoint(best_model_path)
        except Exception as e:
            print("Error loading best model checkpoint: ", e)
            return False
        
        self.model = model    
        return True
    
    def fit(self):            
        self.trainer.fit(
            self.model,
            train_dataloaders=self.train_dataloader,
            val_dataloaders=self.val_dataloader,
        )
    
    def predict(self, x: TimeSeriesDataSet,  return_x: Optional[bool]=False, mode: Optional[str]="prediction", return_y: bool=True):
        
        try:
            tft_predictions = self.model.predict(x, mode=mode, return_x=return_x, return_y=return_y)
        except Exception as e:
            print(f"Failed to predict: {e}")
            return None
        
        return tft_predictions

    @staticmethod
    def find_optimal_parameters(train_dataloader: TimeSeriesDataSet, 
                                val_dataloader: TimeSeriesDataSet,
                                max_epochs: int=50,
                                n_trials: int=100,
                                use_learning_rate_finder: bool=False,
                                model_path: str="optuna_test",
                                best_params_path: str="best_params.pkl",
                                timeout: int=300) -> dict:
        
        """
        Find optimal hyperparameters for a Temporal Fusion Transformer model using Optuna. Best parameters are saved for a potential later usage
        Args:
            train_dataloader (TimeSeriesDataSet): Training dataset loader containing time series data.
            val_dataloader (TimeSeriesDataSet): Validation dataset loader for evaluating model performance.
            max_epochs (int, optional): Maximum number of training epochs per trial. Defaults to 50.
            n_trials (int, optional): Number of optimization trials to run. Defaults to 100.
            use_learning_rate_finder (bool, optional): Whether to use built-in learning rate finder 
                instead of Optuna-based learning rate optimization. Defaults to False.
            model_path (str, optional): Directory path to save model checkpoints during optimization. 
                Defaults to "optuna_test".
            best_params_path (str, optional): File path to save the best hyperparameters. 
                Defaults to "best_params.pkl".
            timeout (int, optional): Maximum time in seconds to run the optimization study. 
                Defaults to 300.
        Returns:
            dict: Dictionary containing the best hyperparameters found during optimization.
        """
        
        # create study
        study = optimize_hyperparameters(
            train_dataloader,
            val_dataloader,
            model_path=model_path,
            n_trials=n_trials,
            max_epochs=max_epochs,
            gradient_clip_val_range=(0.01, 1.0),
            hidden_size_range=(8, 128),
            hidden_continuous_size_range=(8, 128),
            attention_head_size_range=(1, 4),
            learning_rate_range=(0.001, 0.1),
            dropout_range=(0.1, 0.3),
            trainer_kwargs=dict(limit_train_batches=30),
            reduce_on_plateau_patience=4,
            use_learning_rate_finder=use_learning_rate_finder,  # use Optuna to find ideal learning rate or use in-built learning rate finder
            timeout=timeout,  # stop study after given seconds
        )

        # save study results - also we can resume tuning at a later point in time
        
        best_params = study.best_trial.params
        try:
            with open(best_params_path, "wb") as fout:
                pickle.dump(best_params, fout)
                print("Best parameters saved to: ", best_params_path)
        except Exception as e:
            print("Error saving best parameters: ", e)

        # return best hyperparameters
        return best_params


    def plot_raw_predictions(self, raw_predictions, plots_path: str, show=False):

        n = raw_predictions.output.prediction.shape[0]
        print(f"Plotting {n} predictions...")

        for idx in range(n):
            fig = self.model.plot_prediction(
                raw_predictions.x,
                raw_predictions.output,
                idx=idx,
                add_loss_to_title=True
            )
            
            if show:
                plt.show(fig=fig)
                
            fig.savefig(os.path.join(plots_path, f"tft_prediction_{idx}.png"))
            plt.close(fig=fig)
    