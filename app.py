import os
import subprocess
from flask import Flask, jsonify, request

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
AUTH_TOKEN = os.environ.get("X_AUTH_TOKEN", "password")

app = Flask(__name__)

def is_restart_running():
    try:
        # Using "[r]estart.sh" prevents pgrep from matching the pgrep command itself or similar false positives.
        output = subprocess.check_output("pgrep -f '[r]estart.sh'", shell=True, text=True)
        running_pids = [int(pid) for pid in output.strip().split()]
        current_pid = os.getpid()
        # Only consider processes that are not the current Flask process.
        return any(pid != current_pid for pid in running_pids)
    except subprocess.CalledProcessError:
        # No process found.
        return False

def is_ping_successful():
    try:
        result = subprocess.run("docker container exec docker-ap ping -c 1 1.1.1.1", shell=True, text=True, capture_output=True)
        return result.returncode == 0
    except Exception:
        return False

@app.route('/check', methods=['GET'])
def restart():
    # Get the Authorization header from the incoming request
    auth_header = request.headers.get('X-Auth-Token')

    # Check if the header exists and matches the expected token format
    if not auth_header or auth_header != AUTH_TOKEN:
        return jsonify({
            "status": "unauthorized", "message": "Unauthorized"
        }), 401

    force = request.args.get('force')

    # Check if restart.sh is already running
    if is_restart_running():
        return jsonify({"status": "restarting", "message": "Restarting, please wait."}), 409

    # Check connectivity using ping command
    if force != "1" and is_ping_successful():
        return jsonify({
            "status": "heathy", "message": "Heathy"
        }), 200

    try:
        process = subprocess.Popen(
            "./restart.sh",
            cwd=BASE_DIR,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        return jsonify({
            "status": "started",
            "message": "Restart begin, please wait."
        }), 200

    except Exception as e:
        return jsonify({
            "status": "exception",
            "message": str(e)
        }), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
