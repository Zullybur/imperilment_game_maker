require 'build_game'
require 'net/http'
require 'json'
require 'time'

class GameSubmitter
  TOKEN_REGEX = "//meta[@name='csrf-token']"

  def initialize new_uri, user, pwd, count=1, start_date=nil
    # Ensure URL is prefixed and suffixed, then build URI
    new_uri = "http://#{new_uri}" unless new_uri.index("http")
    uri = URI new_uri

    # Get a start date equal to the end date of the last posted game
    start_date = last_game_date(uri) unless start_date

    # Ensure game starts on a Monday
    date = adjust_date_to_monday start_date
    
    gb = GameBuilder.new count

    # Create an imperilment game for each game generated by game builder
    gb.games.each do |rounds|
      Net::HTTP.start uri.host, uri.port do |http|
        result = log_in_response http, uri, user, pwd
        result = create_game_response(
          http,
          uri,
          result['set-cookie'],
          (date + (60*60*24*6)),
        )
        game_id = get_id result, uri

        # Create the categories required for the current game
        rounds.each do |category|
          result = create_category_response(
            http,
            uri,
            result['set-cookie'],
            category.name,
          )
          category_id = get_id result, uri

          # Create the answers for the current category
          category.clues.each do |clue|
            result = create_answer(http, uri, result['set-cookie'],
                                   game_id, category_id, date,
                                   clue.answer, clue.question, clue.value,)

            # Increment date forward one day
            date += (60*60*24) 
          end
        end
      end
    end
  end

  private
  def last_game_date uri
    result = Net::HTTP.start uri.host, uri.port do |http|
      uri.path = "/games.json"
      req = Net::HTTP::Get.new uri
      http.request req
    end
    Time.parse(JSON.parse(result.body).first['ended_at'])
  end

  def get_token body
    Nokogiri.parse(body).xpath(TOKEN_REGEX)[0]['content']
  end

  def get_id result, uri
    first = uri.to_s.length + 1
    result.to_hash["location"][0][(uri.to_s.length + 1)..-1].to_i
  end

  def adjust_date_to_monday date
    tmp = date.dup
    until tmp.monday? do
      tmp += (60*60*24)
    end
    tmp
  end

  def get_response http, uri, cookie=nil
    req = Net::HTTP::Get.new uri
    req['Cookie'] = cookie
    http.request req
  end

  def post_response http, uri, form_data=nil, cookie=nil
    req = Net::HTTP::Post.new uri
    req.set_form_data form_data
    req['Cookie'] = cookie
    http.request req
  end

  def log_in_response http, uri, user, pwd
    # Get form page (for token and cookie)
    uri.path = '/users/sign_in'
    res = get_response http, uri

    # Sign in
    form_data = {
      'authenticity_token': get_token(res.body),
      'user[email]': user,
      'user[password]': pwd,
      'user[remember_me]': 1,
      'commit': 'Sign in',
    }
    post_response http, uri, form_data, res['set-cookie']
  end

  def create_game_response http, uri, cookie, date
    # Get form page (for token and cookie)
    uri.path = '/games/new'
    res = get_response http, uri, cookie

    # Create Game
    uri.path = '/games'
    form_data = {
      'authenticity_token': get_token(res.body),
      'game[ended_at]': date,
      'commit': 'Create Game',
    }
    post_response http, uri, form_data, res['set-cookie']
  end

  def create_category_response http, uri, cookie, name
    # Get form page (for token and cookie)
    uri.path = '/categories/new'
    res = get_response http, uri, cookie

    # Create Category
    uri.path = "/categories"
    form_data = {
      'authenticity_token': get_token(res.body),
      'category[name]': name,
      'commit': 'Create Category',
    }
    post_response http, uri, form_data, res['set-cookie']
  end

  def create_answer http, uri, cookie, game_id, cat_id, date, ans, ques, val
    # Get form page (for token and cookie)
    uri.path = "/games/#{game_id}/answers/new"
    res = get_response http, uri, cookie

    # Create Answer
    uri.path = "/games/#{game_id}/answers"
    form_data = {
      'authenticity_token': get_token(res.body),
      'answer[category_id]': cat_id,
      'answer[answer]': ans,
      'answer[correct_question]': ques,
      'answer[amount]': val,
      'answer[start_date]': date
    }
    post_response http, uri, form_data, res['set-cookie']
  end
end
