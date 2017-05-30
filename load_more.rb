# -*- coding: utf-8 -*-
# -*- frozen_string_literal: true -*-

Plugin.create :load_more do
  # 初期設定
  UserConfig[:load_more_timeline_retrieve_count]     ||= 20
  UserConfig[:load_more_reply_retrieve_count]        ||= 20
  UserConfig[:load_more_list_retrieve_count]         ||= 20
  UserConfig[:load_more_favorite_retrieve_count]     ||= 20
  UserConfig[:load_more_usertimeline_retrieve_count] ||= 20

  # 設定
  settings('load more') do
    settings('一度に取得するつぶやきの件数(1-200)') do
      adjustment('タイムライン', :load_more_timeline_retrieve_count, 1, 200)
      adjustment('リプライ', :load_more_reply_retrieve_count, 1, 200)
      adjustment('リスト', :load_more_list_retrieve_count, 1, 200)
      adjustment('ユーザータイムライン', :load_more_usertimeline_retrieve_count, 1, 200)
      if UserConfig[:favorites_list_retrieve_count]
        adjustment('お気に入り', :load_more_favorite_retrieve_count, 1, 200)
      end
    end
  end

  # mikutter コマンド
  command(:load_more,
          name:      'load more',
          condition: lambda { |opt|
            opt.widget.slug.to_s =~ %r{home_timeline|mentions|own_favourites_list|list_@.+\/.+} ||
              opt.widget.parent.slug.to_s =~ /usertimeline_.+|favorites_list_.+/
          },
          visible:   true,
          role:      :timeline) do |opt|
    case opt.widget.slug.to_s
    when 'home_timeline'
      params = {
        count:  [UserConfig[:load_more_timeline_retrieve_count], 200].min,
        max_id: opt.messages.first[:id] - 1
      }
      Service.primary.home_timeline(params).next { |messages|
        messages.each { |m| timeline(:home_timeline) << m }
      }.trap { |err| error err }
    when 'mentions'
      params = {
        count:  [UserConfig[:load_more_reply_retrieve_count], 200].min,
        max_id: opt.messages.first[:id] - 1
      }
      Service.primary.mentions(params).next { |messages|
        Plugin.call(:update, Service, messages)
        Plugin.call(:mention, Service, messages)
        Plugin.call(:mypost, Service, messages.select(&:from_me?))
      }.terminate
    when %r{list_@(?<screen_name>.+?)\/(?<slug>.+)}
      matched = $LAST_MATCH_INFO
      params  = {
        owner_screen_name: matched['screen_name'],
        slug:              matched['slug'],
        max_id:            opt.messages.first[:id] - 1,
        count:             [UserConfig[:load_more_list_retrieve_count], 200].min,
        include_rts:       1
      }
      Service.primary.list_statuses(params).next { |messages|
        timeline(opt.widget.slug) << messages
      }.terminate
    else
      case opt.widget.parent.slug.to_s
      when /usertimeline_(?<screen_name>.+)_.+_.+_.+/
        matched = $LAST_MATCH_INFO
        params  = {
          screen_name: matched['screen_name'],
          max_id:      opt.messages.first[:id] - 1,
          count:       [UserConfig[:load_more_usertimeline_retrieve_count], 200].min,
          include_rts: 1
        }
        Service.primary.user_timeline(params).next { |messages|
          timeline(opt.widget.slug) << messages
        }.terminate
      when /favorites_list_(?<screen_name>.+)_.+_.+_.+/
        matched = $LAST_MATCH_INFO
        params  = {
          count:  [UserConfig[:load_more_favorite_retrieve_count], 200].min,
          max_id: opt.messages.first[:id] - 1
        }
        Plugin.call(:retrieve_favorites_list,
                    Service,
                    matched['screen_name'],
                    opt.widget.slug, params)
      else
        notice 'nothing to do'
      end
    end
  end
end
