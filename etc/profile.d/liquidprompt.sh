# Il faut avoir installé liquidprompt avec le paquet debian pour que cela fonctionne
# apt install liquidprompt
if [ -f "/usr/share/liquidprompt/liquidprompt" ]; then
    source /usr/share/liquidprompt/liquidprompt
fi

# Sinon installer manuellement liquidprompt dans /opt/liquidprompt/
if [ -f "/opt/liquidprompt/liquidprompt" ]; then
    source /opt/liquidprompt/liquidprompt
fi

