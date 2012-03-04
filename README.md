# LockerBox #

LockerBox is a small script to get you up and running with
[Locker](http://lockerproject.org/) as quickly and easily as possible,
without having to spend a lot of time or effort getting all the
dependencies set up.

At the moment, this is more intended for developers who want to
evaluate Locker than end users. However, this could be a first step
toward a system for building end-user packages of Locker.

## Dependencies ##

There are only a few things that are needed in order to get
Locker up and running using LockerBox:

 - Python 2.6+

 - curl

 - Git

If you are using a recent version of Ubuntu, this should get you set up ready to run LockerBox:

     apt-get install python curl git build-essential libssl-dev make

If you're using Mac OS X you should have all of the dependencies already.


If you don't already have a recent enough version of Node.js installed, it will
be built for you, and installed in the lockerbox directory. How long this takes
will depend on your machine.

Any other dependencies will be automatically downloaded and installed
into lockerbox/local, including:

 - [Node.js](http://nodejs.org)

 - [npm](http://npmjs.org)

 - [virtualenv](http://www.virtualenv.org/)

 - [MongoDB](http://mongodb.org)

 - and various Python and Node.js dependencies

Of course, if you already have recent enough versions of Node.js, npm,
virtualenv, and MongoDB installed, they won't be re-installed
locally. Instead, the already-installed versions will be used.

## Usage ##

    curl https://raw.github.com/LockerProject/lockerbox/master/lockerbox.sh | bash

## And then? ##

At this point, you should have a copy of Locker in lockerbox/Locker. Now start
hacking away!

If something in your environment gets messed up somehow, you can
always blow away lockerbox/local and/or lockerbox/Locker and they will
be auto-filled with dependencies again the next time lockerbox.sh is
run.
