#!/usr/bin/env bash

### Edit your settings here

REPOSITORY=repository_name
REPOSITORY_BUILD=repository_build_name
ORGANISATION=organisation_name
GIT_HOST=github.com

### /!\ Do not edit below unless you known what you do

if [ "" == "$1" ]; then
    echo "Syntax: build.sh <branch>"
    exit 1
fi

GIT_SOURCE_DIR=.
GIT_DEPLOY_DIR=tmp/$REPOSITORY_BUILD
GIT_DEPLOY_REPO=git@$GIT_HOST:$ORGANISATION/$REPOSITORY_BUILD.git
BRANCH=$1
CURRENT_COMMIT=`git show --name-only | grep commit | sed "s/commit //g"`
CURRENT_TAG=`git tag --contains $CURRENT_COMMIT`
RSYNC_EXCLUDES=.git,tmp,build.json,.gitignore,README.md,composer.*,reports,.*,bin/jenkins*,bin/security-checker,app/phpunit.xml.dist,app/cache/*/,app/logs/*.log
COMPOSER_OPTIONS=no-progress,optimize-autoloader,ansi,no-interaction,no-scripts
if [ "master" == "$BRANCH" ]; then
    RSYNC_EXCLUDES=$RSYNC_EXCLUDES,web/app_dev.php
    COMPOSER_OPTIONS=$COMPOSER_OPTIONS,no-dev
fi
RSYNC_OPTIONS=`php -r "echo join(' ', array_map(function (\\$v) {return '--exclude='.\\$v;}, explode(',', '$RSYNC_EXCLUDES')));"`
COMPOSER_OPTIONS=`php -r "echo join(' ', array_map(function (\\$v) {return '--'.\\$v;}, explode(',', '$COMPOSER_OPTIONS')));"`

# download composer if needed

if [ ! -f composer.phar ]; then
    curl -sS https://getcomposer.org/installer | php
else
    ./composer.phar self-update
fi

# execute composer install, and Symfony console commands (no data population here !)

cp app/config/parameters.yml.dist app/config/parameters.yml
./composer.phar install $COMPOSER_OPTIONS
php ./vendor/sensio/distribution-bundle/Sensio/Bundle/DistributionBundle/Resources/bin/build_bootstrap.php
./app/console assets:install --env=prod

# prepare $REPOSITORY_BUILD directory

rm -rf tmp
mkdir -p tmp

if [ ! -d $GIT_DEPLOY_DIR/.git ]; then
    echo "Cloning branch $BRANCH from repo $GIT_DEPLOY_REPO into dir $GIT_DEPLOY_DIR:"
    git clone -b $BRANCH $GIT_DEPLOY_REPO $GIT_DEPLOY_DIR
fi

pushd $GIT_DEPLOY_DIR
git pull
popd

# rsync api to $REPOSITORY_BUILD/ (with excludes)

rsync -r --include="*/.htaccess" $RSYNC_OPTIONS --delete-after $GIT_SOURCE_DIR/ $GIT_DEPLOY_DIR/

# in $REPOSITORY_BUILD: git add ., git commit -m "release ...", git push

pushd $GIT_DEPLOY_DIR
echo "Commit on deploy repo, branch $BRANCH:"
git add . -u
git add .
git commit -am "Automatic Release. Corresponding to commit https://$GIT_HOST/$ORGANISATION/$REPOSITORY/commit/$CURRENT_COMMIT, on $BRANCH branch."
git push origin $BRANCH

# create tag if new one is created
if [ -n "$CURRENT_TAG" ]; then
    echo "Create tag: $CURRENT_TAG"
    RESULT_TAG=`git tag $CURRENT_TAG 2>&1`
    echo $RESULT_TAG
    RESULT_PUSH=`git push origin $CURRENT_TAG 2>&1`
    echo $RESULT_PUSH
    if [[ "$RESULT_TAG $RESULT_PUSH" == *"already exists"* ]]; then
        echo "Recreate existing tag..."
        git tag -d $CURRENT_TAG
        git push origin :refs/tags/$CURRENT_TAG
        git tag $CURRENT_TAG
        git push origin $CURRENT_TAG
    fi
fi
popd
