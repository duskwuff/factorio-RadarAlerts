NAME=$(shell jq -r .name info.json)
VERSION=$(shell jq -r .version info.json)

archive:
	git archive --format=zip --prefix=$(NAME)/ main -o $(NAME)-$(VERSION).zip
