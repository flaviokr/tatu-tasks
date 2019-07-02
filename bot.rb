require 'sinatra'
require 'sinatra/reloader' if development?
require 'http'

before do
  @body = request.body.read
  authenticate_request if request.request_method == 'POST'
end

get '/' do
  'I\'m Healthy'
end

post '/' do
  payload = JSON.parse(@body)
  handle_reaction(payload['event'])
end

post '/list' do
  payload = URI.decode_www_form(@body).to_h
  list_tasks(payload['channel_id'], payload['user_id'])
end

private

def authenticate_request
  data = ['v0', request.get_header('HTTP_X_SLACK_REQUEST_TIMESTAMP'), @body].join(':')
  hexdigest = OpenSSL::HMAC.hexdigest('SHA256', ENV['SIGNING_SECRET'], data)
  expected_signature = "v0=#{hexdigest}"

  request_signature = request.get_header('HTTP_X_SLACK_SIGNATURE')

  halt(401) if request_signature != expected_signature
end

def handle_reaction(event)
  item = event['item']
  channel_id = item['channel']
  message_id = item['ts']
  path_to_file = "tasks/#{channel_id}?p#{message_id.delete('.')}"

  case event['reaction']
  when 'warning'
    unless File.exist?(path_to_file)
      FileUtils.touch(path_to_file)

      Thread.new do
        text = get_message_text(channel_id, message_id)
        File.write(path_to_file, text)
      end
    end
  when 'white_check_mark'
    File.delete(path_to_file) if File.exist?(path_to_file)
  end
end

def list_tasks(channel_id, user_id)
  task_list = Dir['tasks/*'].map.with_index(1) do |task_filename, idx|
    message_ref = task_filename.delete('/tasks').gsub('?', '/')
    label = File.read(task_filename).lines.first.strip[0..100]
    task_link = "*#{idx}.* #{label} <https://playax.slack.com/archives/#{message_ref}|:link:>"
  end

  post_message(channel_id, user_id, task_list.join("\n"))
end

def post_message(channel_id, user_id, text)
  json = { channel: channel_id, user: user_id, text: text }
  HTTP.auth("Bearer #{ENV['BOT_TOKEN']}").post('https://slack.com/api/chat.postEphemeral', json: json)
end

def get_message_text(channel_id, message_id)
  params = { token: ENV['APP_TOKEN'], channel: channel_id, latest: message_id, limit: 1, inclusive: true }
  resp = HTTP.get('https://slack.com/api/conversations.history', params: params)
  json = JSON.parse(resp)
  json.dig('messages', 0, 'text')
end
