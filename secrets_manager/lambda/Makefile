package:
	pip3 download -r requirements.txt
	unzip redis-*.whl
	mkdir -p python
	mv redis python
	zip -r redis.zip python
	zip test_lambda.zip handler.py

clean:
	rm -rf redis*
	rm -rf python
	rm -f test_lambda.zip