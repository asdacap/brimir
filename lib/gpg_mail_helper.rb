
class GpgMailHelper

  def self.logger
    Rails.logger
  end

  def self.assure_public_key_available(email)
    email = email.to_s
    GPGME::Key.find(:public, email)
    if GPGME::Key.find(:public, email).length == 0
      hkp = Hkp.new(AppSettings.gpg_key_server)
      ids = hkp.search(email)
      return false if ids.length == 0
      ifs.each do |id|
        hkp.fetch_and_import(id)
      end
    end
    true
  end

  def self.decrypt_if_encrypted email
    # If public key is needed, check if the public key is in keychain. 
    # If not obtain it

    if AppSettings.gpg_mail_verification_required || email.encrypted?
      return nil unless assure_public_key_available(email.from[0])
    end

    if email.encrypted?
      options = {}
      options[:password] = AppSettings.gpg_mail_private_key_passphrase if AppSettings.gpg_mail_private_key_passphrase.blank?
      options[:verify] = AppSettings.gpg_mail_verification_required
      email = email.decrypt(options)
      if (AppSettings.gpg_mail_verification_required || email.signed?) && !email.signature_valid?
        logger.error "Email signature invalid"
        logger.error "Email from #{email.from}"
        return nil
      end
    else
      if AppSettings.gpg_mail_encryption_required
        return nil
      end

      if AppSettings.gpg_mail_verification_required && !email.signed?
        logger.error "Verification is required but email is not signed."
        logger.error "Email from #{email.from}"
        return nil
      end
      if AppSettings.gpg_mail_verification_required || email.signed?
        email = email.verify
        unless email.signature_valid?
          logger.error "Email signature invalid"
          logger.error "Email from #{email.from}"
          return nil
        end
      end
    end
    email
  end
end
