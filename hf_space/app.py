import gradio asアプリ
from gradio_client import Client
import os

# Script pour Hugging Face Space
# Modèle: GalsenAI/xtts-v2-wolof

import gradio as gr
from TTS.api import TTS
import torch

# Load model
device = "cuda" if torch.cuda.is_available() else "cpu"
tts = TTS("vosstts/xtts-v2-wolof").to(device)

def generate_wolof_speech(text):
    output_path = "output.wav"
    tts.tts_to_file(
        text=text,
        file_path=output_path,
        speaker_wav="female_voice_sample.wav", # Optionnel: échantillon de voix pour le cloning
        language="wo"
    )
    return output_path

demo = gr.Interface(
    fn=generate_wolof_speech,
    inputs=gr.Textbox(label="Texte en Wolof"),
    outputs=gr.Audio(label="Audio généré"),
    title="Wolof TTS for Tontetic"
)

if __name__ == "__main__":
    demo.launch()
