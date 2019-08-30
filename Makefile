version ?= 0.3.1

all: tag_old_image build rm_old_image

build:
	docker build . -t tatu-tasks:$(version)

tag_old_image:
	-docker tag tatu-tasks:$(version) tatu-tasks:$(version)-old 2>/dev/null

rm_old_image:
	-docker rmi tatu-tasks:$(version)-old 2>/dev/null


clean: stop
	-docker rm tatu-tasks
	-docker rmi tatu-tasks:$(version)
	-docker rmi gcr.io/playax18/tatu-tasks:$(version)

run:
	docker run --rm -it --name tatu-tasks -v $(PWD):/tatu-tasks -p 9292:9292 -e APP_ENV=development -e RACK_ENV=development tatu-tasks:$(version)

stop:
	-docker stop tatu-tasks

version_check:
	@( read -p "Deploy version $(version)? [y/n] " ans && case "$$ans" in [yY]) true;; *) false;; esac )

deploy: version_check all
	docker tag tatu-tasks:$(version) gcr.io/playax18/tatu-tasks:$(version)
	docker push gcr.io/playax18/tatu-tasks:$(version)
	docker rmi gcr.io/playax18/tatu-tasks:$(version)
	sed -E 's/gcr\.io\/playax18\/tatu-tasks\:[0-9.]+/gcr.io\/playax18\/tatu-tasks:$(version)/g' kubernetes.yaml > temp_kube.yaml
	mv temp_kube.yaml kubernetes.yaml
	kubectl apply -f kubernetes.yaml
