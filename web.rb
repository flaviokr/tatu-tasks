require 'sinatra'
require 'sinatra/reloader' if development?
require 'http'
require 'google/cloud/firestore'

FIRESTORE = Google::Cloud::Firestore.new(project_id: ENV['GCP_PROJECT_ID'])
WORKSPACE = 'playax'

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
  post_message(payload['channel_id'], payload['user_id'], list_tasks)
end

post '/interaction' do
  payload = JSON.parse(URI.decode_www_form(@body)[0][1])
  action = payload.dig('actions', 0, 'value')
  response_url = payload['response_url']

  case action
  when 'update' then update_message(response_url, list_tasks)
  when 'delete' then delete_message(response_url)
  end
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

  task_doc_id = "#{channel_id}-#{message_id}"
  document_query = FIRESTORE.col("workspaces/#{WORKSPACE}/tasks").doc(task_doc_id)

  case event['reaction']
  when 'warning'
    unless document_query.get.exists?
      document_query.set(
        channel_id: channel_id,
        message_ts: message_id,
        text: get_message_text(channel_id, message_id)
      )
    end
  when 'done'
    document_query.delete
  end
end

def list_tasks
  tasks_collection = FIRESTORE.col('workspaces').doc(WORKSPACE).col('tasks').get
  tasks = tasks_collection.map.with_index(1) do |task, idx|
    channel_id, message_ts, text = task.data.values_at(:channel_id, :message_ts, :text)
    label = text&.lines&.first&.strip&.slice(0, 70)
    task_link = "*#{idx}.* #{label} <https://playax.slack.com/archives/#{channel_id}/#{message_ts}|:link:>"
  end

  tasks = ['Não há tarefas pendentes. Eba :tada:'] if tasks.empty?

  message_blocks = [
    build_section(tasks.join("\n")),
    build_actions([build_button(:Fechar, :delete), build_button(:Atualizar, :update)])
  ]
end

def build_section(text)
  build_text_block(:section, text, text_type: :mrkdwn)
end

def build_button(text, value)
  build_text_block(:button, text, value: value)
end

def build_actions(elements)
  { type: :actions, elements: elements }
end

def build_text_block(type, text, opts = {})
  text_type = opts.delete(:text_type) || :plain_text
  { type: type, text: { type: text_type, text: text } }.merge(opts)
end

def post_message(channel_id, user_id, blocks)
  json = { channel: channel_id, user: user_id, blocks: blocks }
  auth_slack_http.post('https://slack.com/api/chat.postEphemeral', json: json)
end

def update_message(response_url, blocks)
  auth_slack_http.post(response_url, json: { blocks: blocks, replace_original: true })
end

def delete_message(response_url)
  auth_slack_http.post(response_url, json: { delete_original: true })
end

def auth_slack_http
  HTTP.auth("Bearer #{ENV['BOT_TOKEN']}")
end

def get_message_text(channel_id, message_id)
  params = { token: ENV['APP_TOKEN'], channel: channel_id, latest: message_id, limit: 1, inclusive: true }
  resp = HTTP.get('https://slack.com/api/conversations.history', params: params)
  json = JSON.parse(resp)
  json.dig('messages', 0, 'text')
end
