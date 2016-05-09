# Build script

This script is use to pre-compilate the project before deploying to production environnement. You must create a target repository with all vendor commited.

It is mainly use for Symfony 2 project. It can be adapted for any project.

## How to use

Copy build.sh file in bin/ directory.

Create a repository to host all source code with vendor. Example: my-project-deploy

Create develop and master branch in build repository (my-project-deploy).

Modify setting part in build.sh file.

```
REPOSITORY=my-project
REPOSITORY_BUILD=my-project-deploy
ORGANISATION=francetv
GIT_HOST=github.com
```

Then, execute the script ```bin/build.sh```

## How it works

* Download composer
* Copy config file
* Install all vendor with optimized autoload
* Build bootstrap cache file for Symfony 2
* Copy assets
* Cloning repository build into tmp/ directory
* Synchronize current source file with build repository via rsync
* Create new commit and pushing code
* Create tag if exist

---------------------------------------
This project is part of [francetv zoom open source projects](https://gitlab.ftven.net/team-infini/zoom-public) (iOS, Android and Angular)