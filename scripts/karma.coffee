# Description:
#   Track arbitrary karma
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   <thing>++ - give thing some karma
#   <thing>-- - take away some of thing's karma
#   hubot karma <thing> - check thing's karma (if <thing> is omitted, show the top 5)
#   hubot karma empty <regex> - empty a thing's karma
#   hubot karma best - show the top 5
#   hubot karma worst - show the bottom 5
#   hubot karma all - show everything that has positive or negative karma
#   hubot karma filter <regex> - show everything that matches thing
#
# Author:
#   stuartf

_ = require("underscore")

class Karma

  constructor: (@robot) ->
    @cache = {}

    @increment_responses = [
      "+1!",
      "gained a level!",
      "is on the rise!",
      "leveled up!",
      "<3",
      ":legoclap:",
      ":highfive:",
      ":upgreydd:",
      ":)",
      ":godmode:",
      ":clap:",
      ":thumbsup:",
      ":arrow_double_up:",
      ":chart_with_upwards_trend:"
    ]

    @decrement_responses = [
      "-1!",
      "lost a level.",
      "took a hit! Ouch.",
      "took a dive.",
      "lost a life.",
      ":(",
      ":burn:",
      ":dangerzone:",
      ":nobueno:",
      ":poop:",
      ":hurtrealbad:",
      ":runforitmarty:",
      ":thumbsdown:",
      ":chart_with_downwards_trend:",
      ":arrow_double_down:"
    ]

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.karma
        @cache = @robot.brain.data.karma

  kill: (thing) ->
    delete @cache[thing]
    @robot.brain.data.karma = @cache

  increment: (thing) ->
    @cache[thing] ?= 0
    @cache[thing] += 1
    @robot.brain.data.karma = @cache

  decrement: (thing) ->
    @cache[thing] ?= 0
    @cache[thing] -= 1
    @robot.brain.data.karma = @cache

  incrementResponse: ->
     @increment_responses[Math.floor(Math.random() * @increment_responses.length)]

  decrementResponse: ->
     @decrement_responses[Math.floor(Math.random() * @decrement_responses.length)]

  get: (thing) ->
    k = if @cache[thing] then @cache[thing] else 0
    return k

  sort: ->
    s = []
    for key, val of @cache
      s.push({ name: key, karma: val })
    s.sort (a, b) -> b.karma - a.karma

  fragments: (sortby='unique', limit=10)->
    b = {}
    for key, val of @cache
      bits = _.uniq(key.split('_'))
      for bit in bits
        bit = bit.toLowerCase()
        if !b[bit]
          b[bit] = { name: bit, unique: 0, total: 0 }
        b[bit]['unique'] += 1
        b[bit]['total'] += val

    s = _.toArray(b)

    s.sort (a, b) ->
      if (sortby == 'name' || b[sortby] - a[sortby] == 0)
        return 1 if a.name > b.name
        return -1 if a.name < b.name
        0
      else
        b[sortby] - a[sortby]

    if limit == 0 then s else s.slice(0, limit)

  longest: ->
    sorted = @sort()
    filtered = ''
    max = 0
    for thing in sorted
      if thing.name.length > max
        filtered= thing.name
        max = thing.name.length
    filtered

  top: (n = 5) ->
    sorted = @sort()
    sorted.slice(0, n)

  bottom: (n = 5) ->
    sorted = @sort()
    sorted.slice(-n).reverse()

  nonzero: ->
    sorted = @sort()
    nz = []
    for thing in sorted
      if thing.karma != 0
        nz.push(thing)
    nz

  filter: (filter) ->
    sorted = @sort()
    filtered = []
    for thing in sorted
      if thing.name.search(filter) > -1
        filtered.push(thing)
    filtered

  clean_display_name: (name) ->
    item_name = name.replace /@/, "@ "

module.exports = (robot) ->
  karma = new Karma robot
  robot.hear /^([^+:\s]*)[: ]*\+\+(?:\s+.*?)?$/, (msg) ->
    subject = msg.match[1].toLowerCase()
    karma.increment subject
    response = karma.incrementResponse()
    numKarma = karma.get(subject)
    if numKarma % 10 == 0
      response = "Courage and wit have served thee well. Thou hast been promoted " +
                 "to the next level.\nThy Maximum Hit Points increase by #{numKarma / 10}."
      if numKarma % 30 == 0
        response = response + "\nThou hast learned a new spell."
      msg.send "#{subject} (Karma: #{karma.get(subject)})\n#{response}"
    else
      msg.send "#{subject} #{response} (Karma: #{karma.get(subject)})"

  robot.hear /^([^-:\s]*)[: ]*--(?:\s+.*?)?$/, (msg) ->
    subject = msg.match[1].toLowerCase()
    karma.decrement subject
    msg.send "#{subject} #{karma.decrementResponse()} (Karma: #{karma.get(subject)})"

  robot.respond /karma empty ?(\S+[^-\s])$/i, (msg) ->
    match = msg.match[1].toLowerCase()
    verbiage = ["All Matching Karma"]
    for item, rank in karma.filter(match)
      verbiage.push "#{karma.clean_display_name(item.name)} (#{item.karma}) has had its karma scattered to the winds."
      karma.kill item.name
    msg.send verbiage.join("\n")

  robot.respond /karma filter ?(\S+[^-\s])$/i, (msg) ->
    match = msg.match[1].toLowerCase()
    verbiage = ["All Matching Karma"]
    for item, rank in karma.filter(match)
      verbiage.push "#{rank + 1}. #{karma.clean_display_name(item.name)} - #{item.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma bits(.*)$/i, (msg) ->
    args = msg.match[1].toLowerCase().split(/\s+/)

    limit = 10
    for arg in args
      if arg == 'all'
        limit = 0
      else if parseInt(arg) > 0
        limit = arg

    sort = 'unique'
    sort = 'name' if _.indexOf(args, 'name') > -1
    sort = 'total' if _.indexOf(args, 'total') > -1

    verbiage = ["The Pieces of Karma"]
    for item, rank in karma.fragments(sort, limit)
      verbiage.push "#{karma.clean_display_name(item.name)} - #{item.unique} unique, #{item.total} total"
    msg.send verbiage.join("\n")

  robot.respond /karma longest$/i, (msg) ->
    verbiage = ["The Longest Karma"]
    subject = karma.longest()
    verbiage.push "#{subject} Karma: #{karma.get(subject)}"
    msg.send verbiage.join("\n")

  robot.respond /karma( best)?$/i, (msg) ->
    verbiage = ["The Best"]
    for item, rank in karma.top()
      verbiage.push "#{rank + 1}. #{karma.clean_display_name(item.name)} - #{item.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma worst$/i, (msg) ->
    verbiage = ["The Worst"]
    for item, rank in karma.bottom()
      verbiage.push "#{rank + 1}. #{karma.clean_display_name(item.name)} - #{item.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma all$/i, (msg) ->
    verbiage = ["All Karma"]
    for item, rank in karma.nonzero()
      verbiage.push "#{rank + 1}. #{karma.clean_display_name(item.name)} - #{item.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma (\S+[^-\s])$/i, (msg) ->
    match = msg.match[1].toLowerCase()
    if match != "best" && match != "worst" && match != "all" && match != "bits"
      msg.send "\"#{match}\" has #{karma.get(match)} karma."
