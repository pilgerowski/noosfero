require "uri"

module Api
  module V1
    class Session < Grape::API

      # Login to get token
      #
      # Parameters:
      #   login (*required) - user login or email
      #   password (required) - user password
      #
      # Example Request:
      #  POST http://localhost:3000/api/v1/login?login=adminuser&password=admin
      post "/login" do
        begin
          user ||= User.authenticate(params[:login], params[:password], environment)
          @plugins.each do |plugin|
            user ||= plugin.alternative_authentication
            break unless user.nil?
          end
        rescue User::UserNotActivated => e
          render_api_error!(e.message, Api::Status::Http::UNAUTHORIZED)
        end

        return unauthorized! unless user
        @current_user = user
        present user, :with => Entities::UserLogin, :current_person => current_person
      end

      # Logout to remove all user information from session
      #
      # Example Request:
      #  POST http://localhost:3000/api/v1/logout
      post "/logout" do
	current_user.forget_me
	current_user.update({:chat_status_at => DateTime.now}.merge({:last_chat_status => current_user.chat_status, :chat_status => 'offline'}))
	reset_session
        output = {:success => true}
	output[:message] = _('Logout successfully.')
        output[:code] = Api::Status::LOGOUT
        present output, :with => Entities::Response
      end

      post "/login_from_cookie" do
        return unauthorized! if cookies[:auth_token].blank?
        user = User.where(remember_token: cookies[:auth_token]).first
        return unauthorized! unless user && user.activated?
        @current_user = user
        present user, :with => Entities::UserLogin, :current_person => current_person
      end

      # Create user.
      #
      # Parameters:
      #   email (required)                  - Email
      #   password (required)               - Password
      #   login                             - login
      # Example Request:
      #   POST /register?email=some@mail.com&password=pas&password_confirmation=pas&login=some
      params do
        requires :email, type: String, desc: _("Email")
        requires :login, type: String, desc: _("Login")
        requires :password, type: String, desc: _("Password")
      end

      post "/register" do
        attrs = attributes_for_keys [:email, :login, :password, :password_confirmation] + environment.signup_person_fields
        name = params[:name].present? ? params[:name] : attrs[:email]
        attrs[:password_confirmation] = attrs[:password] if !attrs.has_key?(:password_confirmation)
        user = User.new(attrs.merge(:name => name))

        begin
          user.signup!
          user.generate_private_token! if user.activated?
          present user, :with => Entities::UserLogin, :current_person => user.person
        rescue ActiveRecord::RecordInvalid
          render_model_errors!(user.errors)
        end
      end

      params do
        requires :activation_code, type: String, desc: _("Activation token")
      end

      # Activate a user.
      #
      # Parameter:
      #   activation_code (required)                  - Activation token
      # Example Request:
      #   PATCH /activate?activation_code=28259abd12cc6a64ef9399cf3286cb998b96aeaf
      patch "/activate" do
        user = User.find_by activation_code: params[:activation_code]
        if user
          unless user.environment.enabled?('admin_must_approve_new_users')
            if user.activate
                user.generate_private_token!
                present user, :with => Entities::UserLogin, :current_person => current_person
            end
          else
            if user.create_moderate_task
              user.activation_code = nil
              user.save!

              # Waiting for admin moderate user registration
              status 202
              body({
                :message => 'Waiting for admin moderate user registration'
              })
            end
          end
        else
          # Token not found in database
          render_api_error!(_('Token is invalid'), 412)
        end
      end

      # Request a new password.
      #
      # Parameters:
      #   value (required)                  - Email or login
      # Example Request:
      #   POST /forgot_password?value=some@mail.com
      post "/forgot_password" do
        requestors = fetch_requestors(params[:value])
        not_found! if requestors.blank?
        remote_ip = (request.respond_to?(:remote_ip) && request.remote_ip) || (env && env['REMOTE_ADDR'])
        requestors.each do |requestor|
          ChangePassword.create!(:requestor => requestor)
        end

        output = {:success => true}
	output[:message] = _('All change password requests were sent.')
        output[:code] = Api::Status::Http::OK
        present output, :with => Entities::Response
      end

      # Resend activation code.
      #
      # Parameters:
      #   value (required)                  - Email or login
      # Example Request:
      #   POST /resend_activation_code?value=some@mail.com
      post "/resend_activation_code" do
        requestors = fetch_requestors(params[:value])
        not_found! if requestors.blank?
        remote_ip = (request.respond_to?(:remote_ip) && request.remote_ip) || (env && env['REMOTE_ADDR'])
        requestors.each do |requestor|
          requestor.user.resend_activation_code
        end
        present requestors.map(&:user), :with => Entities::UserLogin
      end

      params do
        requires :code, type: String, desc: _("Forgot password code")
      end
      # Change password
      #
      # Parameters:
      #   code (required)                  - Change password code
      #   password (required)
      #   password_confirmation (required)
      # Example Request:
      #   PATCH /new_password?code=xxxx&password=secret&password_confirmation=secret
      patch "/new_password" do
        begin
          change_password = ChangePassword.find_by! code: params[:code]
          change_password.update_attributes!(:password => params[:password], :password_confirmation => params[:password_confirmation])
          change_password.finish
          present change_password.requestor.user, :with => Entities::UserLogin, :current_person => current_person
        rescue ActiveRecord::RecordInvalid => ex
          render_model_errors!(change_password.errors)
        rescue Exception => ex
          render_api_error!(ex.message, Api::Status::Http::BAD_REQUEST)
        end
      end

    end
  end
end
