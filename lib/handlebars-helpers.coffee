module.exports = (ctx) ->
  literal: (content) -> content
  dockervolumes: (data)->
    root = data.data.root
    @volumes?.reduce (prev, volume) =>
      parsed = volume.match /^((\/[^:]+)|(\/[^:]+):(\/[^:]+))(:ro|:rw)?(:shared|:do_not_persist)?$/
      if parsed
        [all, ignore, simplePath, mappedPathExt, mappedPathInt, permissions, options] = parsed
        mapping = "#{root.dataDir}/#{root.project}/#{root.instance}/#{@service}#{simplePath}:#{simplePath}"
        if mappedPathExt
          if options is ':shared'
            mapping = "#{root.sharedDataDir}/#{root.project}#{mappedPathExt}:#{mappedPathInt}"
          else
            mapping = "#{root.dataDir}/#{root.project}/#{root.instance}/#{@service}#{mappedPathExt}:#{mappedPathInt}"
        if options is ':do_not_persist' then mapping = simplePath or mappedPathInt
        "#{prev}-v #{mapping}#{permissions or ''} "
      else
        console.error "Invalid volume mapping: #{volume}"
        prev
    , ""

  volumesfrom: (data) ->
    root = data.data.root
    volumesFrom = @['volumes-from'] or @['volumes_from']
    volumesFrom?.reduce (prev, volume) ->
      "#{prev}--volumes-from #{volume}-#{root.project}-#{root.instance} "
    , ""

  attribute: attribute = (attrName, attrPrefix) ->
    @[attrName]?.reduce (left, right) =>
      acc = "#{right}".replace /"/g, '\\"'
      "#{left}#{attrPrefix}\"#{acc}\" "
    , ""
  environmentAttributes: ->
    if @environment and Array.isArray @environment
      attribute.call @, 'environment', '-e '
    else
      ("-e '#{key}=#{value}'" for key, value of @environment).join ' '


  mapDocker: (context) ->
    console.log 'mapDocker', @, context
    if context.mapDocker or context.map_docker
      context.fn(this)
    else context.inverse(this)

  syslogUrl: -> ctx.syslogUrl

  eachReverse: (context) ->
    # from: https://github.com/diy/handlebars-helpers/blob/master/lib/each-reverse.js
    options = arguments[arguments.length - 1]
    ret = '';
    if context and context.length > 0
      i = context.length - 1
      while i >= 0
        ret = "#{ret}#{options.fn(context[i])}"
        i--
    else
      ret = options.inverse(this)
    ret

  stringify: JSON.stringify

  dashboardUrl: (data)->
    root = data.data.root
    root.dashboardUrl
