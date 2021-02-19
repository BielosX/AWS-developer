cd /home/ec2-user/webapps/HelloApp || exit
python3 -m venv /home/ec2-user/webapps/HelloApp
source bin/activate
pip3 install -r requirements.txt
bin/gunicorn -w 4 -b 0.0.0.0:5000 hello:app -D
ps -e | grep gunicorn
command -v python3