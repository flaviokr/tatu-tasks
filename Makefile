version ?= 0.2.3

all: tag_old_image build rm_old_image

build:
	docker build . -t slacktionic:$(version)

tag_old_image:
	-docker tag slacktionic:$(version) slacktionic:$(version)-old 2>/dev/null

rm_old_image:
	-docker rmi slacktionic:$(version)-old 2>/dev/null


clean: stop
	-docker rm slacktionic
	-docker rmi slacktionic:$(version)
	-docker rmi gcr.io/playax18/slacktionic:$(version)

run:
	docker run --rm -it --name slacktionic -v $(PWD):/slacktionic -p 9292:9292 -e APP_ENV=development -e RACK_ENV=development slacktionic:$(version)

stop:
	-docker stop slacktionic

version_check:
	@( read -p "Deploy version $(version)? [y/n] " ans && case "$$ans" in [yY]) true;; *) false;; esac )

deploy: version_check all
	docker tag slacktionic:$(version) gcr.io/playax18/slacktionic:$(version)
	docker push gcr.io/playax18/slacktionic:$(version)
	docker rmi gcr.io/playax18/slacktionic:$(version)
	sed -E 's/gcr\.io\/playax18\/slacktionic\:[0-9.]+/gcr.io\/playax18\/slacktionic:$(version)/g' kubernetes.yaml > temp_kube.yaml
	mv temp_kube.yaml kubernetes.yaml
	kubectl apply -f kubernetes.yaml
