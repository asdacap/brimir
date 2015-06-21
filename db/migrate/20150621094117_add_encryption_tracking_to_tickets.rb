class AddEncryptionTrackingToTickets < ActiveRecord::Migration
  def change
    change_table :tickets do |t|
      t.boolean :from_email, default: false
      t.boolean :encrypted, default: false
      t.boolean :signed, default: false
      t.boolean :signature_valid, default: false
    end
    change_table :replies do |t|
      t.boolean :from_email, default: false
      t.boolean :encrypted, default: false
      t.boolean :signed, default: false
      t.boolean :signature_valid, default: false
    end
  end
end
