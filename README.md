# Indelible — A syncing tool for SimpleNote

I'm a big fan of the [Notational Velocity][1] way of life, but use a Linux desktop most of the day. Of the kind who uses emacs, to top it all, and wishes to remain ensconsced in its tight embrace.

As part of my Friday Hack routine, I've taken upon writing a sync backend for SimpleNote. The idea is simple: start running when you login, forget about it, deal with simple text files and let it do its trick. Right now it's still missing the little daemon that will keep everything working, but manual syncs go well, and I'm happy with what I have for only a few hours of work.

## Running

First of all, install [bundler][2]. 

  $ gem install bundler

Download *Indelible* and go to its directory. Install the bundle.

  $ cd indelible
  $ bundle install

Run *indelible* and answer its questions.

  $ ./indelible start
  Let's create your config file before using Indelible.
  You will only need to provide your SimpleNote credentials and a folder to store your text files.
 
  SimpleNote username: <your username>
  SimpleNote password: <your password>
  Folder: <local folder>

Let it roll.

From here on you can add *indelible start* to your shell's profile/login file, using its full path. Magic will happen automatically.

## TODO

- Create gem
- Avoid filename conflicts

[1]: http://notational.net/
[2]: http://gembundler.com/


