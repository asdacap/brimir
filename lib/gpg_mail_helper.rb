
class GpgMailHelper

  def self.logger
    Rails.logger
  end

  def self.assure_public_key_available(email)
    email = email.to_s
    logger.info "Assure public key for email #{email}"
    GPGME::Key.find(:public, email)
    if GPGME::Key.find(:public, email).length == 0
      logger.info "Key not available locally. Fetching from #{AppSettings.gpg_key_server}"
      hkp = Hkp.new(AppSettings.gpg_key_server)
      ids = hkp.search(email)
      if ids.length == 0
        logger.info "No key found"
        return false
      else
        logger.info "#{ids.length} keys found"
      end
      ids.each do |id|
        hkp.fetch_and_import(id[0])
      end
    end
    true

  rescue OpenURI::HTTPError => e
    logger.error "Failed to assure public key for #{email}."
    if e.io.status[0] == "404"
      logger.error "Key not found"
    else
      logger.error "Exception: #{e.class.name}"
      logger.error "Message: #{e.message}"
      logger.error "Backtrace: #{e.backtrace.join("\n")}"
    end
    false
  end

  def self.decrypt_if_encrypted email
    # If public key is needed, check if the public key is in keychain. 
    # If not obtain it

    if AppSettings.gpg_mail_verification_required || email.encrypted? || email.signed?
      unless assure_public_key_available(email.from[0])
        logger.info "Fail to get key for #{email}."
        return nil
      end
    end

    encrypted = email.encrypted?
    signed = false
    signature_valid = false

    if email.encrypted?
      logger.info "Email is encrypted"

      options = {}
      options[:password] = AppSettings.gpg_mail_private_key_passphrase unless AppSettings.gpg_mail_private_key_passphrase.blank?
      options[:verify] = AppSettings.gpg_mail_verification_required

      email = email.decrypt(options)
      logger.info "Decryption successful"

      signed = email.signed?

      if (AppSettings.gpg_mail_verification_required || email.signed?) && !email.signature_valid?
        logger.error "Email signature invalid"
        logger.error "Email from #{email.from}"
        if AppSettings.gpg_mail_ignore_bad_signature
          logger.error "Server has been configured to ignore bad signature"
        else
          return nil
        end
      else
        signature_valid = true
        logger.info "Signature valid"
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
        signed = email.signed?
        logger.info "Email is signed"
        email = email.verify
        unless email.signature_valid?
          logger.error "Email signature invalid"
          logger.error "Email from #{email.from}"
          if AppSettings.gpg_mail_ignore_bad_signature
            logger.error "Server has been configured to ignore bad signature"
          else
            return nil
          end
        else
          signature_valid = true
          logger.info "Signature valid"
        end
      else
        logger.info "Email is not encrypted nor signed"
      end
    end
    return email, encrypted, signed, signature_valid
  end
end
