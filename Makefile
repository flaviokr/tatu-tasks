all:
	docker build . -t slacktionic

run:
	docker run --rm --name slacktionic -v $(pwd):/slacktionic -p 80:9292 slacktionic

