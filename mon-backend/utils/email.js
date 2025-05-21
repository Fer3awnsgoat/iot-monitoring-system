const nodemailer = require('nodemailer');

console.log('SMTP Config:', {
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  user: process.env.SMTP_USER,
  from: process.env.EMAIL_FROM
});

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: process.env.SMTP_PORT,
  secure: process.env.SMTP_PORT == 465, // true for 465, false for 587
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

transporter.verify(function(error, success) {
  if (error) {
    console.error('SMTP connection error:', error);
  } else {
    console.log('SMTP server is ready to take messages');
  }
});

async function sendEmail({ to, subject, html }) {
  const maxRetries = 3;
  let retryCount = 0;

  while (retryCount < maxRetries) {
    try {
      const info = await transporter.sendMail({
        from: process.env.EMAIL_FROM,
        to,
        subject,
        html,
      });
      console.log('Email sent successfully:', info.messageId);
      return info;
    } catch (error) {
      retryCount++;
      console.error(`Failed to send email (attempt ${retryCount}/${maxRetries}):`, error);
      
      if (retryCount === maxRetries) {
        throw new Error(`Failed to send email after ${maxRetries} attempts: ${error.message}`);
      }
      
      // Wait before retrying (exponential backoff)
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
    }
  }
}

module.exports = { transporter, sendEmail };
