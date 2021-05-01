package:
	pip3 install -r requirements.txt -t ${PWD}
	zip test_lambda.zip handler.py
	zip -r test_lambda.zip redis

clean:
	rm -rf redis*
	rm -f test_lambda.zip