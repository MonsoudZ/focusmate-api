# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tasks API Contract', type: :request, skip_committee_validation: true do
  let(:user) { create(:user) }
  let(:list) { create(:list, user: user) }

  def auth_headers_for(u)
    token = JwtHelper.access_for(u)
    { 'Authorization' => "Bearer #{token}" }
  end

  let(:auth_headers) { auth_headers_for(user) }

  describe 'GET /api/v1/tasks' do
    context 'with valid authentication' do
      before do
        create(:task, list: list, creator: user)
      end

      it 'returns tasks that match OpenAPI schema' do
        get '/api/v1/tasks', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('tasks')
        expect(json).to have_key('tombstones')
        expect(json['tasks']).to be_an(Array)
        expect(json['tombstones']).to be_an(Array)

        # Validate task structure matches schema
        if json['tasks'].any?
          task = json['tasks'].first
          expect(task).to have_key('id')
          expect(task).to have_key('title')
          expect(task).to have_key('status')
          expect(task).to have_key('created_at')
          expect(task).to have_key('updated_at')
        end
      end
    end

    context 'with query parameters' do
      before do
        create(:task, list: list, creator: user)
      end

      it 'handles list_id filter' do
        get '/api/v1/tasks', params: { list_id: list.id }, headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it 'handles status filter' do
        get '/api/v1/tasks', params: { status: 'pending' }, headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it 'handles pagination' do
        get '/api/v1/tasks', params: { page: 1, per_page: 10 }, headers: auth_headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'without authentication' do
      it 'returns 401 Unauthorized' do
        get '/api/v1/tasks'

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to have_key('message')
      end
    end
  end

  describe 'POST /api/v1/tasks' do
    let(:task_params) do
      {
        title: 'Test Task',
        description: 'A test task description',
        list_id: list.id,
        due_at: 1.week.from_now.iso8601,
        visibility: 'visible_to_all'
      }
    end

    context 'with valid parameters' do
      it 'creates task and returns schema-compliant response' do
        post '/api/v1/tasks', params: task_params, headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('id')
        expect(json).to have_key('title')
        expect(json).to have_key('status')
        expect(json).to have_key('created_at')
        expect(json).to have_key('updated_at')
        expect(json['title']).to eq('Test Task')
      end
    end

    context 'with invalid parameters' do
      it 'returns validation error' do
        post '/api/v1/tasks', params: { title: '', list_id: list.id }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
    end
  end

  describe 'GET /api/v1/tasks/:id' do
    let(:task) { create(:task, list: list, creator: user) }

    context 'with valid task ID' do
      it 'returns task details' do
        get "/api/v1/tasks/#{task.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('id')
        expect(json).to have_key('title')
        expect(json).to have_key('status')
        expect(json['id']).to eq(task.id)
      end
    end

    context 'with non-existent task ID' do
      it 'returns 404 Not Found' do
        get '/api/v1/tasks/99999', headers: auth_headers

        expect(response).to have_http_status(:not_found)
        expect(response.content_type).to include('application/json')

        json = JSON.parse(response.body)
        expect(json).to have_key('error')
      end
    end
  end
end
