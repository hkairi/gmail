require 'mime/message'

module Gmail
  class Message
    # Raised when given label doesn't exists.
    class NoLabelError < Exception; end 
  
    attr_reader :uid
    
    def initialize(mailbox, uid)
      @uid     = uid
      @mailbox = mailbox
      @gmail   = mailbox.instance_variable_get("@gmail") if mailbox
    end
    
    def uid
      @uid ||= @gmail.conn.uid_search(['HEADER', 'Message-ID', message_id])[0]
    end
    
    # Mark message with given flag.
    def flag(name)
      !!@gmail.mailbox(@mailbox.name) { @gmail.conn.uid_store(uid, "+FLAGS", [name]) }
    end
    
    # Unmark message. 
    def unflag(name)
      !!@gmail.mailbox(@mailbox.name) { @gmail.conn.uid_store(uid, "-FLAGS", [name]) }
    end
    
    # Do commonly used operations on message. 
    def mark(flag)
      case flag
        when :read    then read!
        when :unread  then unread!
        when :deleted then delete!
        when :spam    then spam!
      else
        flag(flag)
      end
    end
    
    # Mark this message as a spam.
    def spam!
      move_to('[Gmail]/Spam')
    end
    
    # Mark as read.
    def read!
      flag(:Seen)
    end
    
    # Mark as unread.
    def unread!
      unflag(:Seen)
    end
    
    # Mark message with star.
    def star!
      flag('[Gmail]/Starred')
    end
    
    # Remove message from list of starred.
    def unstar!
      unflag('[Gmail]/Starred')
    end
    
    # Move to trash.
    def delete!
      @mailbox.messages.delete(uid)
      flag(:Deleted)
    end

    # Archive this message.
    def archive!
      move_to('[Gmail]/All Mail')
    end
    
    # Move to given box and delete from others.  
    def move_to(name, from=nil)
      label(name, from) && delete!
    end
    alias :move :move_to
    
    # Move message to given and delete from others. When given mailbox doesn't 
    # exist then it will be automaticaly created. 
    def move_to!(name, from=nil)
      label!(name, from) && delete!
    end
    alias :move! :move_to!
    
    # Mark this message with given label. When given label doesn't exist then
    # it will raise <tt>NoLabelError</tt>. 
    #
    # See also <tt>Gmail::Message#label!</tt>.
    def label(name, from=nil)
      @gmail.mailbox(from || @mailbox.name) { @gmail.conn.uid_copy(uid, name) }
    rescue Net::IMAP::NoResponseError
      raise NoLabelError, "Label '#{name}' doesn't exist!"
    end
    alias :add_label :label

    # Mark this message with given label. When given label doesn't exist then
    # it will be automaticaly created. 
    #
    # See also <tt>Gmail::Message#label</tt>.
    def label!(name, from=nil)
      label(name, from) 
    rescue NoLabelError
      @gmail.labels.add(name)
      label!(name, from)
    end
    alias :add_label! :add_label
    
    # Remove given label from this message. 
    def remove_label!(name)
      move_to('[Gmail]/All Mail', name)
    end
    alias :delete_label! :remove_label!
    
    def inspect
      "#<Gmail::Message#{'0x%04x' % (object_id << 1)} mailbox=#{@mailbox.name}#{' uid='+@uid.to_s if @uid}#{' message_id='+@message_id.to_s if @message_id}>"
    end
    
    def method_missing(meth, *args, &block)
      # Delegate rest directly to the message.  
      message.send(meth, *args, &block)
    end
    
    private
    
    def message
      @message ||= Mail.new(@gmail.mailbox(@mailbox.name) { 
        @gmail.conn.uid_fetch(uid, "RFC822")[0].attr["RFC822"] 
      })
    end
  end # Message
end # Gmail
