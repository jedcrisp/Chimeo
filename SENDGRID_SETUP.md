# SendGrid Email Integration Setup Guide

This guide explains how to set up and configure the SendGrid email service for LocalAlert organization approval notifications.

## Overview

The LocalAlert app now includes a complete SendGrid email integration that automatically sends:
- **Approval emails** when organizations are approved
- **Rejection emails** when organizations are rejected (with structured reasons)
- **More info request emails** when additional information is needed

## Features

- ✅ **Professional HTML email templates** with Chimeo branding
- ✅ **Structured content parsing** for rejection reasons and info requests
- ✅ **Rate limiting** to prevent API abuse
- ✅ **Retry logic** with exponential backoff
- ✅ **Error handling** with fallback to console logging
- ✅ **Environment-aware** configuration

## Configuration

### 1. Email Configuration (`EmailConfig.swift`)

The app is pre-configured with:
- **API Key**: `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`
- **From Email**: `noreply@chimeo.com`
- **From Name**: `Chimeo Team`
- **Support Email**: `support@chimeo.com`

### 2. Rate Limiting

- **Max emails per minute**: 100
- **Max retry attempts**: 3
- **Retry delay**: 5 seconds

## Email Templates

### Approval Email
- **Subject**: "Your Organization Has Been Approved - LocalAlert"
- **Content**: Welcome message with next steps and platform access information

### Rejection Email
- **Subject**: "Organization Review Update - LocalAlert"
- **Content**: Clear rejection reason with actionable next steps

### More Info Request Email
- **Subject**: "Additional Information Needed - LocalAlert"
- **Content**: Structured list of required information with submission instructions

## Admin Review System

### Enhanced Review Interface

The admin review system now includes:

#### More Info Request Options
- Business License
- Tax Exempt Status
- Insurance Documentation
- Address Verification
- Contact Information Verification
- Mission Statement
- Operational Details
- Custom Request

#### Rejection Reason Options
- Incomplete Information
- Invalid Address
- Unverified Contact
- Duplicate Organization
- Outside Service Area
- Inappropriate Content
- Verification Failed
- Custom Reason

### Structured Input

- **Visual selection** with icons and colors
- **Custom input fields** for additional details
- **Automatic formatting** for email content
- **Validation** to ensure required fields are completed

## How It Works

### 1. Admin Review Process
1. Admin selects review status (Approve/Reject/More Info)
2. Admin selects structured options (info types or rejection reasons)
3. Admin adds custom details if needed
4. Admin writes review notes
5. System formats content and sends email

### 2. Email Sending Process
1. **Content parsing**: Structured input is parsed and formatted
2. **Template generation**: HTML and plain text versions are created
3. **SendGrid API call**: Email is sent via SendGrid's API
4. **Rate limiting**: Prevents API abuse
5. **Retry logic**: Handles temporary failures
6. **Error handling**: Falls back to console logging if needed

### 3. Email Content Structure

#### More Info Requests
```
Information requested: Business License, Tax Exempt Status

Additional details: Please provide current copies of both documents

Review notes: Organization looks good, just need verification documents
```

#### Rejection Reasons
```
Rejection reason: Incomplete Information

Specific details: Missing business license and tax exempt status

Review notes: Cannot proceed without proper documentation
```

## Testing

### Development Mode
- Emails are sent to actual recipients
- Console logging shows email status
- Rate limiting is active but generous

### Production Mode
- Full email functionality
- Strict rate limiting
- Comprehensive error handling

## Troubleshooting

### Common Issues

#### 1. Email Not Sending
- Check SendGrid API key validity
- Verify rate limiting settings
- Check console for error messages

#### 2. Content Formatting Issues
- Ensure structured input is properly selected
- Check custom input fields
- Verify review notes are entered

#### 3. API Rate Limits
- Reduce email frequency
- Increase rate limiting values
- Check SendGrid account limits

### Debug Information

The system provides detailed logging:
- ✅ Email sent successfully
- ❌ Failed to send email: [error description]
- 📧 Creator account notifications
- 🔄 Retry attempts and delays

## Security Considerations

- **API Key Protection**: Stored in code (consider environment variables for production)
- **Rate Limiting**: Prevents API abuse
- **Input Validation**: Structured input prevents injection attacks
- **Error Handling**: No sensitive information in error messages

## Future Enhancements

- [ ] **Email tracking** and analytics
- [ ] **Template customization** through admin interface
- [ ] **Bulk email** capabilities
- [ **Email preferences** for users
- [ ] **Alternative email providers** (Mailgun, AWS SES)

## Support

For technical support or questions about the email system:
- **Email**: support@chimeo.com
- **Documentation**: This guide and inline code comments
- **Console Logs**: Detailed debugging information in Xcode console

---

**Note**: This system is designed to be robust and user-friendly while maintaining professional communication standards. All emails are automatically formatted and sent, reducing admin workload and ensuring consistent messaging.
