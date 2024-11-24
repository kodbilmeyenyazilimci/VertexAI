// model_data.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ModelData {
  static List<Map<String, dynamic>> models(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context)!;

    return [
      {
        'title': appLocalizations.modelTinyLlamaTitle,
        'description': appLocalizations.modelTinyLlamaDescription,
        'url': 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf?download=true',
        'size': appLocalizations.modelTinyLlamaSize,
        'image': 'assets/tinyllama.png',
        'ram': appLocalizations.modelTinyLlamaRam,
        'producer': appLocalizations.modelTinyLlamaProducer,
        'isServerSide': false,
        'canHandleImage': false
      },
      {
        'title': appLocalizations.modelPhiTitle,
        'description': appLocalizations.modelPhiDescription,
        'url': 'https://huggingface.co/timothyckl/phi-2-instruct-v1/resolve/23d6e417677bc32b1fb4947615acbb616556142a/ggml-model-q4km.gguf?download=true',
        'size': appLocalizations.modelPhiSize,
        'image': 'assets/phi.png',
        'ram': appLocalizations.modelPhiRam,
        'producer': appLocalizations.modelPhiProducer,
        'isServerSide': false,
        'canHandleImage': false
      },
      {
        'title': appLocalizations.modelMistralTitle,
        'description': appLocalizations.modelMistralDescription,
        'url': 'https://huggingface.co/sayhan/Mistral-7B-Instruct-v0.2-turkish-GGUF/resolve/main/mistral-7b-instruct-v0.2-turkish.Q5_K_M.gguf?download=true',
        'size': appLocalizations.modelMistralSize,
        'image': 'assets/mistral.png',
        'ram': appLocalizations.modelMistralRam,
        'producer': appLocalizations.modelMistralProducer,
        'isServerSide': false,
        'canHandleImage': false
      },
      {
        'title': appLocalizations.modelGemmaTitle,
        'description': appLocalizations.modelGemmaDescription,
        'url': 'https://huggingface.co/ggml-org/gemma-1.1-7b-it-Q4_K_M-GGUF/resolve/main/gemma-1.1-7b-it.Q4_K_M.gguf?download=true',
        'size': appLocalizations.modelGemmaSize,
        'image': 'assets/gemma.png',
        'ram': appLocalizations.modelGemmaRam,
        'producer': appLocalizations.modelGemmaProducer,
        'isServerSide': false,
        'canHandleImage': false
      },
      {
        'title': appLocalizations.modelGPTNeoXTitle,
        'description': appLocalizations.modelGPTNeoXDescription,
        'url': 'https://huggingface.co/zhentaoyu/gpt-neox-20b-Q4_0-GGUF/resolve/main/gpt-neox-20b-q4_0.gguf',
        'size': appLocalizations.modelGPTNeoXSize,
        'image': 'assets/neo.png',
        'ram': appLocalizations.modelGPTNeoXRam,
        'producer': appLocalizations.modelGPTNeoXProducer,
        'isServerSide': false,
        'canHandleImage': false
      },
      {
        'title': 'Gemini',
        'description': appLocalizations.modelGeminiDescription,
        'url': 'no', // No download URL for server-side models
        'size': '45 GB', // No size needed
        'image': 'assets/gemini.png',
        'ram': '16 GB RAM', // No RAM requirement
        'producer': 'Google',
        'isServerSide': true,
        'canHandleImage': false
      },
      {
        'title': 'Llama3.2',
        'description': appLocalizations.modelLlamaDescription,
        'url': 'no', // No download URL for server-side models
        'size': '60 GB', // No size needed
        'image': 'assets/llama.png',
        'ram': '32 GB RAM', // No RAM requirement
        'producer': 'Meta',
        'isServerSide': true,
        'canHandleImage': false
      },
      {
        'title': 'Hermes',
        'description': appLocalizations.modelHermesDescription,
        'url': 'no', // No download URL for server-side models
        'size': '180 GB', // No size needed
        'image': 'assets/hermes.png',
        'ram': '64 GB RAM', // No RAM requirement
        'producer': 'Nous Research',
        'isServerSide': true,
        'canHandleImage': true
      },
    ];
  }
}
