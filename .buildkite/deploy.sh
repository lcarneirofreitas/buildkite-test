#!/bin/bash

# Verifica se um argumento foi passado
if [ -z "$1" ]; then
  echo "Erro: Nenhum argumento fornecido."
  exit 1
fi

# Retorna o primeiro argumento
echo "Ambiente selecionado: $1"
