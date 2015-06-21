
# Make sure it is loaded
Mail::Gpg::Rails::ActionMailerPatch

module GpgMailerPatch
  extend ActiveSupport::Concern

  included do
    alias_method_chain :mail, :brimir
  end

  def mail_with_brimir(headers = {}, &block)
    headers[:gpg] ||= {}
    headers[:gpg][:password] ||= AppSettings.gpg_mail_private_key_passphrase
    headers[:gpg][:sign] ||= AppSettings.gpg_mail_always_sign_outgoing_mail
    headers[:gpg][:encrypt] ||= AppSettings.gpg_mail_always_encrypt_outgoing_mail

    if headers[:gpg][:encrypt]
      unless GpgMailHelper.assure_public_key_available(headers[:to])
        headers[:gpg][:encrypt] = false
        Rails.logger.error "Fail to retrieve public key for #{headers[:to]}. Encryption is disabled."
      end
    end

    if headers[:gpg]
      unless(headers[:gpg][:sign] || headers[:gpg][:encrypt])
        headers.delete(:gpg)
      end
    end

    mail_without_brimir(headers,&block)
  end
end

ActionMailer::Base.send :include, GpgMailerPatch
