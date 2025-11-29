#!/bin/sh
# Wings Configuration CGI Script
# Serves both the HTML interface and handles API requests

PACKAGE="pterodactyl_panel"
VAR_DIR="/var/packages/${PACKAGE}/var"
WINGS_CONFIG="${VAR_DIR}/data/wings/config.yml"
WINGS_PID_FILE="${VAR_DIR}/wings.pid"

# Parse query string
parse_query() {
    echo "$QUERY_STRING" | tr '&' '\n' | while read param; do
        key=$(echo "$param" | cut -d'=' -f1)
        value=$(echo "$param" | cut -d'=' -f2- | sed 's/+/ /g' | sed 's/%/\\x/g' | xargs -0 printf '%b')
        eval "QUERY_${key}=\"${value}\""
    done
}

# Send JSON response
send_json() {
    echo "Content-Type: application/json"
    echo ""
    echo "$1"
}

# Send HTML response
send_html() {
    echo "Content-Type: text/html; charset=utf-8"
    echo ""
    cat << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configuration Wings - Pterodactyl</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #fff;
            padding: 20px;
        }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { font-size: 1.5rem; margin-bottom: 20px; text-align: center; }
        .card {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        .card h2 {
            font-size: 1rem;
            margin-bottom: 15px;
            color: #4fc3f7;
        }
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8rem;
        }
        .status-running { background: rgba(76, 175, 80, 0.2); color: #81c784; }
        .status-stopped { background: rgba(244, 67, 54, 0.2); color: #e57373; }
        .instructions {
            background: rgba(79, 195, 247, 0.1);
            border-left: 3px solid #4fc3f7;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 0 8px 8px 0;
            font-size: 0.9rem;
        }
        .instructions ol { margin-left: 20px; line-height: 1.8; }
        .instructions code {
            background: rgba(0, 0, 0, 0.3);
            padding: 2px 6px;
            border-radius: 4px;
        }
        textarea {
            width: 100%;
            height: 350px;
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            color: #c9d1d9;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            padding: 15px;
            resize: vertical;
        }
        textarea:focus {
            outline: none;
            border-color: #4fc3f7;
        }
        .button-row {
            display: flex;
            gap: 10px;
            margin-top: 15px;
            justify-content: flex-end;
        }
        button {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            font-size: 0.9rem;
            cursor: pointer;
            transition: all 0.2s;
        }
        .btn-primary {
            background: linear-gradient(135deg, #4fc3f7 0%, #29b6f6 100%);
            color: #000;
        }
        .btn-primary:hover { transform: translateY(-2px); }
        .btn-secondary {
            background: rgba(255, 255, 255, 0.1);
            color: #fff;
        }
        .alert {
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 15px;
            display: none;
        }
        .alert-success {
            background: rgba(76, 175, 80, 0.2);
            border: 1px solid rgba(76, 175, 80, 0.3);
            color: #81c784;
        }
        .alert-error {
            background: rgba(244, 67, 54, 0.2);
            border: 1px solid rgba(244, 67, 54, 0.3);
            color: #e57373;
        }
        .loading { text-align: center; padding: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Configuration Wings</h1>

        <div class="card">
            <h2>Status Wings <span id="wingsStatus" class="status-badge status-stopped">Chargement...</span></h2>
        </div>

        <div class="card">
            <h2>Instructions</h2>
            <div class="instructions">
                <ol>
                    <li>Dans le <strong>Panel</strong>, allez dans <code>Admin</code> &rarr; <code>Nodes</code> &rarr; <code>Create New</code></li>
                    <li>Configurez le Node avec le FQDN de votre NAS</li>
                    <li>Cliquez sur l'onglet <code>Configuration</code> puis <code>Generate Token</code></li>
                    <li><strong>Copiez tout le YAML</strong> et collez-le ci-dessous</li>
                </ol>
            </div>
        </div>

        <div id="alertSuccess" class="alert alert-success"></div>
        <div id="alertError" class="alert alert-error"></div>

        <div class="card">
            <h2>Configuration YAML</h2>
            <textarea id="configEditor" placeholder="Collez la configuration YAML..."></textarea>
            <div class="button-row">
                <button class="btn-secondary" onclick="loadConfig()">Recharger</button>
                <button class="btn-primary" onclick="saveConfig()">Enregistrer &amp; Redemarrer</button>
            </div>
        </div>
    </div>

    <script>
        const CGI_URL = '/webman/3rdparty/pterodactyl_panel/wings-config.cgi';

        async function loadConfig() {
            hideAlerts();
            try {
                const response = await fetch(CGI_URL + '?action=get_config');
                const data = await response.json();
                if (data.success) {
                    document.getElementById('configEditor').value = data.config || '';
                } else {
                    showError(data.error || 'Erreur de chargement');
                }
            } catch (e) {
                showError('Erreur: ' + e.message);
            }
            checkStatus();
        }

        async function saveConfig() {
            const config = document.getElementById('configEditor').value.trim();
            if (!config) {
                showError('La configuration ne peut pas etre vide');
                return;
            }
            hideAlerts();
            try {
                const response = await fetch(CGI_URL + '?action=save_config', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: 'config=' + encodeURIComponent(config)
                });
                const data = await response.json();
                if (data.success) {
                    showSuccess('Configuration enregistree ! Wings redemarre...');
                    setTimeout(checkStatus, 3000);
                } else {
                    showError(data.error || 'Erreur de sauvegarde');
                }
            } catch (e) {
                showError('Erreur: ' + e.message);
            }
        }

        async function checkStatus() {
            try {
                const response = await fetch(CGI_URL + '?action=status');
                const data = await response.json();
                const badge = document.getElementById('wingsStatus');
                if (data.running) {
                    badge.className = 'status-badge status-running';
                    badge.textContent = 'En cours';
                } else {
                    badge.className = 'status-badge status-stopped';
                    badge.textContent = data.configured ? 'Arrete' : 'Non configure';
                }
            } catch (e) {
                document.getElementById('wingsStatus').textContent = 'Erreur';
            }
        }

        function showSuccess(msg) {
            const el = document.getElementById('alertSuccess');
            el.textContent = msg;
            el.style.display = 'block';
        }

        function showError(msg) {
            const el = document.getElementById('alertError');
            el.textContent = msg;
            el.style.display = 'block';
        }

        function hideAlerts() {
            document.getElementById('alertSuccess').style.display = 'none';
            document.getElementById('alertError').style.display = 'none';
        }

        document.addEventListener('DOMContentLoaded', loadConfig);
        setInterval(checkStatus, 15000);
    </script>
</body>
</html>
HTMLEOF
}

# Check Wings status
check_status() {
    running="false"
    configured="false"

    if [ -f "${WINGS_CONFIG}" ]; then
        configured="true"
    fi

    if [ -f "${WINGS_PID_FILE}" ]; then
        pid=$(cat "${WINGS_PID_FILE}" 2>/dev/null)
        if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
            running="true"
        fi
    fi

    send_json "{\"success\":true,\"running\":${running},\"configured\":${configured}}"
}

# Get config
get_config() {
    if [ -f "${WINGS_CONFIG}" ]; then
        config=$(cat "${WINGS_CONFIG}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        send_json "{\"success\":true,\"config\":\"${config}\"}"
    else
        send_json "{\"success\":true,\"config\":\"\",\"message\":\"No config found\"}"
    fi
}

# Save config
save_config() {
    # Read POST data
    read -n "${CONTENT_LENGTH}" POST_DATA

    # Extract config from POST data (URL encoded)
    config=$(echo "${POST_DATA}" | sed 's/^config=//' | sed 's/+/ /g' | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null)

    if [ -z "${config}" ]; then
        send_json "{\"success\":false,\"error\":\"Configuration vide\"}"
        return
    fi

    # Create directory if needed
    mkdir -p "$(dirname "${WINGS_CONFIG}")" 2>/dev/null

    # Save config
    echo "${config}" > "${WINGS_CONFIG}"
    chmod 640 "${WINGS_CONFIG}"

    # Restart Wings via synopkg
    synopkg restart "${PACKAGE}" >/dev/null 2>&1 &

    send_json "{\"success\":true,\"message\":\"Configuration saved\"}"
}

# Main router
case "${QUERY_STRING}" in
    *action=status*)
        check_status
        ;;
    *action=get_config*)
        get_config
        ;;
    *action=save_config*)
        save_config
        ;;
    *)
        send_html
        ;;
esac
