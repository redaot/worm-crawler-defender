#!/usr/bin/env bash
# Worm-Crawler Defender - test inofensiv. made by REDAOT
# Ruleaza o comanda de tip "descarca-si-ruleaza" care decodeaza doar cuvantul 'true'.
# Paza ar trebui sa BLOCHEZE internetul si sa afiseze alerta in cateva secunde.
echo "Test: rulez o comanda codificata INOFENSIVA (decodeaza doar 'true')."
echo "In cateva secunde internetul ar trebui sa se blocheze si sa apara alerta."
echo "Deblochezi apoi cu:  sudo wcd-unlock"
echo
# 'dHJ1ZQo=' = base64 pentru "true"
echo 'dHJ1ZQo=' | base64 -d | bash
echo "Comanda de test a rulat. Asteapta reactia pazei..."
