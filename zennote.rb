#!/usr/bin/env ruby
require 'lib/simplenote'

syncer = ZenNote::SyncBackend.new 'dodecaphonic@gmail.com', 'm0rgaine', 'test'
syncer.sync
