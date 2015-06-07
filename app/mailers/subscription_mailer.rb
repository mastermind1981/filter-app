class SubscriptionMailer < ActionMailer::Base
  default from: 'noreply@hrfilter.de'
  def confirmation_mail(subscription)
    @subscription = subscription
    mail to: subscription.email, subject: '[HRfilter] Bestätigung des E-Mail-Abos'
  end

  def newsletter(mailing)
    @mailing = mailing
    if mailing.can_send?
      mail to: subscription.email, subject: '[HRfilter] Newsletter'
    end
  end
end