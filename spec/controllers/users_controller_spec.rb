require "rails_helper"

describe UsersController, type: :controller do
  let(:root) { users(:root) }
  let(:acme_root) { users(:acme_root) }
  let(:acme_normal) { users(:acme_normal) }
  let(:acme_normal_password) { "Normalpwd123" }
  let(:foo_inc_root) { users(:foo_inc_root) }
  let(:foo_inc_normal) { users(:foo_inc_normal) }

  let(:acme) { organizations(:acme) }

  def create_user(options)
    user = User.create! name: "Temporary User",
                        primary_number: "(408) 543-5432",
                        email: "temp_user@stockaid-temp-domain.com",
                        password: "Password1",
                        role: "none"
    OrganizationUser.create! organization: options[:at], user: user, role: options[:role]
    user
  end

  describe "GET index" do
    it "is not allowed for normal users" do
      expect do
        signed_in_user :acme_normal
        get :index
      end.to raise_error(PermissionError)
    end

    it "shows all users for super admin" do
      signed_in_user :root
      get :index
      expect(assigns(:users)).to include(root, acme_root, acme_normal, foo_inc_root, foo_inc_normal)
    end

    it "shows users that the user has access to" do
      signed_in_user :acme_root
      get :index
      expect(assigns(:users)).to include(acme_root, acme_normal)
      expect(assigns(:users)).to_not include(root, foo_inc_root, foo_inc_normal)
    end
  end

  describe "GET deleted" do
    it "is not allowed for non-super admin users"
    it "returns users without organizations"
  end

  describe "GET edit" do
    it "is allowed for normal users to edit themselves" do
      signed_in_user :acme_normal
      get :edit, id: acme_normal.id.to_s
      expect(assigns(:user)).to eq(acme_normal)
    end

    it "is allowed for admin users to edit other users at their organization" do
      signed_in_user :acme_root
      get :edit, id: acme_normal.id.to_s
      expect(assigns(:user)).to eq(acme_normal)
    end

    it "is allowed for admin users to edit other admin users at their organization" do
      acme_root_2 = create_user(at: acme, role: "admin")
      signed_in_user :acme_root
      get :edit, id: acme_root_2.id.to_s
      expect(assigns(:user)).to eq(acme_root_2)
    end

    it "is allowed for super admin users to edit normal users" do
      signed_in_user :root
      get :edit, id: acme_normal.id.to_s
      expect(assigns(:user)).to eq(acme_normal)
    end

    it "is allowed for super admin users to edit admin users" do
      signed_in_user :root
      get :edit, id: acme_root.id.to_s
      expect(assigns(:user)).to eq(acme_root)
    end

    it "is not allowed for normal users to edit another normal user" do
      expect do
        acme_normal_2 = create_user(at: acme, role: "none")
        signed_in_user :acme_normal
        get :edit, id: acme_normal_2.id.to_s
      end.to raise_error(PermissionError)
    end

    it "is not allowed for admin users to edit normal users at another organization" do
      expect do
        signed_in_user :acme_root
        get :edit, id: foo_inc_normal.id.to_s
      end.to raise_error(PermissionError)
    end

    it "is not allowed for admin users to edit admin users at another organization" do
      expect do
        signed_in_user :acme_root
        get :edit, id: foo_inc_root.id.to_s
      end.to raise_error(PermissionError)
    end
  end

  describe "PUT update" do
    it "fails for normal users editing another user" do
      expect do
        acme_normal_2 = create_user(at: acme, role: "none")
        signed_in_user :acme_normal
        put :update, id: acme_normal_2.id.to_s, user: {
          name: "Changed Name",
          email: "changed@stockaid-temp-domain.com",
          primary_number: "(408) 555-5432"
        }
      end.to raise_error(PermissionError)
    end

    it "fails for admin users editing normal users at another organization" do
      expect do
        signed_in_user :acme_root
        put :update, id: foo_inc_normal.id.to_s, user: {
          name: "Changed Name",
          email: "changed@stockaid-temp-domain.com",
          primary_number: "(408) 555-5432"
        }
      end.to raise_error(PermissionError)
    end

    it "fails for admin users editing admin users at another organization" do
      expect do
        signed_in_user :acme_root
        put :update, id: foo_inc_root.id.to_s, user: {
          name: "Changed Name",
          email: "changed@stockaid-temp-domain.com",
          primary_number: "(408) 555-5432"
        }
      end.to raise_error(PermissionError)
    end

    it "updates user details if done by the same user" do
      signed_in_user :acme_normal
      put :update, id: acme_normal.id.to_s, user: {
        name: "Changed Name",
        email: "changed@stockaid-temp-domain.com",
        primary_number: "(408) 555-5432"
      }
      acme_normal.reload
      expect(acme_normal.name).to eq("Changed Name")
      expect(acme_normal.email).to eq("changed@stockaid-temp-domain.com")
      expect(acme_normal.primary_number).to eq("(408) 555-5432")
    end

    it "updates user details if done by a super admin" do
      signed_in_user :root
      put :update, id: acme_normal.id.to_s, user: {
        name: "Changed Name",
        email: "changed@stockaid-temp-domain.com",
        primary_number: "(408) 555-5432"
      }
      acme_normal.reload
      expect(acme_normal.name).to eq("Changed Name")
      expect(acme_normal.email).to eq("changed@stockaid-temp-domain.com")
      expect(acme_normal.primary_number).to eq("(408) 555-5432")
    end

    it "doesn't update user details if done by an admin" do
      signed_in_user :acme_root
      put :update, id: acme_normal.id.to_s, user: {
        name: "Changed Name",
        email: "changed@stockaid-temp-domain.com",
        primary_number: "(408) 555-5432"
      }
      acme_normal.reload
      expect(acme_normal.name).to_not eq("Changed Name")
      expect(acme_normal.email).to_not eq("changed@stockaid-temp-domain.com")
      expect(acme_normal.primary_number).to_not eq("(408) 555-5432")
    end

    it "doesn't update password if not provided" do
      signed_in_user :acme_normal
      put :update, id: acme_normal.id.to_s
      acme_normal.reload
      expect(acme_normal.valid_password?(acme_normal_password)).to be_truthy
    end

    it "fails if the passwords don't match" do
      signed_in_user :acme_normal

      expect(put(:update, id: acme_normal.id.to_s, user: {
                   current_password: acme_normal_password,
                   password: "MismatchedPwd1",
                   password_confirmation: "MisMatchedPwd2"
                 })).to render_template(:edit)

      expect(assigns(:user).errors).to be_present
      acme_normal.reload
      expect(acme_normal.valid_password?(acme_normal_password)).to be_truthy
    end

    it "fails if the passwords aren't complex enough" do
      signed_in_user :acme_normal

      expect(put(:update, id: acme_normal.id.to_s, user: {
                   current_password: acme_normal_password,
                   password: "simplepwd1",
                   password_confirmation: "simplepwd1"
                 })).to render_template(:edit)

      expect(assigns(:user).errors).to be_present
      acme_normal.reload
      expect(acme_normal.valid_password?(acme_normal_password)).to be_truthy
    end

    it "fails if the original passwords is incorrect" do
      signed_in_user :acme_normal

      expect(put(:update, id: acme_normal.id.to_s, user: {
                   current_password: "InvalidOriginalPassword1",
                   password: "NewValidPassword1",
                   password_confirmation: "NewValidPassword1"
                 })).to render_template(:edit)

      expect(assigns(:user).errors).to be_present
      acme_normal.reload
      expect(acme_normal.valid_password?(acme_normal_password)).to be_truthy
    end

    it "changes the user's password if provided" do
      signed_in_user :acme_normal
      put :update, id: acme_normal.id.to_s, user: {
        current_password: acme_normal_password,
        password: "NewValidPassword1",
        password_confirmation: "NewValidPassword1"
      }
      acme_normal.reload
      expect(acme_normal.valid_password?(acme_normal_password)).to be_falsey
      expect(acme_normal.valid_password?("NewValidPassword1")).to be_truthy
    end

    it "sends an email notification to the email address if the password is changed" do
      signed_in_user :acme_normal

      expect do
        put :update, id: acme_normal.id.to_s, user: {
          current_password: acme_normal_password,
          password: "NewValidPassword1",
          password_confirmation: "NewValidPassword1"
        }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(ActionMailer::Base.deliveries.last.to).to match_array(acme_normal.email)
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to include(acme_normal.name)
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to match(/password has changed/i)
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to_not include("NewValidPassword1")
    end

    it "sends two email notifications to the old email address if the password and email is changed" do
      original_email = acme_normal.email
      signed_in_user :acme_normal

      expect do
        put :update, id: acme_normal.id.to_s, user: {
          name: "Changed Name",
          email: "changed@stockaid-temp-domain.com",
          primary_number: "(408) 555-5432",
          current_password: acme_normal_password,
          password: "NewValidPassword1",
          password_confirmation: "NewValidPassword1"
        }
      end.to change { ActionMailer::Base.deliveries.count }.by(2)

      expect(ActionMailer::Base.deliveries.first.to).to match_array(original_email)
      expect(ActionMailer::Base.deliveries.last.to).to match_array(original_email)
      expect(ActionMailer::Base.deliveries.first.body.parts.last.to_s).to include("Changed Name")
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to include("Changed Name")

      if ActionMailer::Base.deliveries.first.body.parts.last.to_s.include?(original_email)
        email_notification_body = ActionMailer::Base.deliveries.first.body.parts.last.to_s
        password_notification_body = ActionMailer::Base.deliveries.last.body.parts.last.to_s
      else
        password_notification_body = ActionMailer::Base.deliveries.first.body.parts.last.to_s
        email_notification_body = ActionMailer::Base.deliveries.last.body.parts.last.to_s
      end

      expect(email_notification_body).to include(original_email)
      expect(email_notification_body).to include("changed@stockaid-temp-domain.com")
      expect(password_notification_body).to_not include(original_email)
      expect(password_notification_body).to_not include("changed@stockaid-temp-domain.com")

      expect(password_notification_body).to match(/password has changed/i)
      expect(email_notification_body).to_not match(/password has changed/i)
    end

    it "doesn't change roles if done by the same user when a normal user" do
      signed_in_user :acme_normal
      put :update, id: acme_normal.id.to_s, roles: {
        acme.id.to_s => "admin"
      }
      acme_normal.reload
      expect(acme_normal.role_at(acme)).to_not eq("admin")
    end

    it "changes roles if done by the same user when an admin" do
      signed_in_user :acme_root
      put :update, id: acme_root.id.to_s, roles: {
        acme.id.to_s => "none"
      }
      acme_root.reload
      expect(acme_root.role_at(acme)).to eq("none")
    end

    it "changes roles if done by an admin" do
      signed_in_user :acme_root
      put :update, id: acme_normal.id.to_s, roles: {
        acme.id.to_s => "admin"
      }
      acme_normal.reload
      expect(acme_normal.role_at(acme)).to eq("admin")
    end

    it "changes roles if done by a super admin" do
      signed_in_user :root
      put :update, id: acme_normal.id.to_s, roles: {
        acme.id.to_s => "admin"
      }
      acme_normal.reload
      expect(acme_normal.role_at(acme)).to eq("admin")
    end

    it "changes role if done by a super admin" do
      signed_in_user :root
      put :update, id: acme_normal.id.to_s, user: { role: "admin" }

      acme_normal.reload
      expect(acme_normal.role).to eq("admin")
    end

    it "fails to change role if _not_ done by a super admin" do
      signed_in_user :acme_root
      put :update, id: acme_normal.id.to_s, user: { role: "admin" }

      acme_normal.reload
      expect(acme_normal.role).to_not eq("admin")
    end

    it "sends an email notification to the old email address if the email is changed" do
      original_email = acme_normal.email
      signed_in_user :acme_normal

      expect do
        put :update, id: acme_normal.id.to_s, user: {
          name: "Changed Name",
          email: "changed@stockaid-temp-domain.com",
          primary_number: "(408) 555-5432"
        }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(ActionMailer::Base.deliveries.last.to).to match_array(original_email)
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to include("Changed Name")
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to include(original_email)
      expect(ActionMailer::Base.deliveries.last.body.parts.last.to_s).to include("changed@stockaid-temp-domain.com")
    end

    it "doesn't send an email notification to the email if it doesn't change" do
      original_email = acme_normal.email
      signed_in_user :acme_normal
      put :update, id: acme_normal.id.to_s, user: {
        name: "Changed Name",
        email: original_email,
        primary_number: "(408) 555-5432"
      }
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "doesn't drop organization access if done by the same user when a normal user"
    it "drops organization access if done by the same user when an admin"
  end

  describe "DELETE destroy" do
    it "prevents deleting when the user doesn't have access"
    it "allows deleting when the user has access"
  end
end
