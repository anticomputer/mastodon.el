;;; mastodon-auth-test.el --- Tests for mastodon-auth.el  -*- lexical-binding: nil -*-

(require 'el-mock)

(ert-deftest mastodon-auth--handle-token-response--good ()
  "Should extract the access token from a good response."
  (should
   (string=
    "foo"
    (mastodon-auth--handle-token-response
     '(:access_token "foo" :token_type "Bearer" :scope "read write follow" :created_at 0)))))

(ert-deftest mastodon-auth--handle-token-response--unknown ()
  "Should throw an error when the response is unparsable."
  (should
   (equal
    '(error "Unknown response from mastodon-auth--get-token!")
    (condition-case error
        (progn
          (mastodon-auth--handle-token-response '(:herp "derp"))
          nil)
      (t error)))))

(ert-deftest mastodon-auth--handle-token-response--failure ()
  "Should throw an error when the response indicates an error."
  (let ((error-message "The provided authorization grant is invalid, expired, revoked, does not match the redirection URI used in the authorization request, or was issued to another client."))
    (should
     (equal
      `(error ,(format "Mastodon-auth--access-token: invalid_grant: %s" error-message))
      (condition-case error
          (mastodon-auth--handle-token-response
           `(:error "invalid_grant" :error_description ,error-message))
        (t error))))))

(ert-deftest mastodon-auth--get-token ()
  "Should generate token and return JSON response."
  (with-temp-buffer
    (with-mock
      (mock (mastodon-auth--generate-token) => (progn
                                                 (insert "\n\n{\"access_token\":\"abcdefg\"}")
                                                 (current-buffer)))
      (should
       (equal (mastodon-auth--get-token)
              '(:access_token "abcdefg"))))))

(ert-deftest mastodon-auth--access-token-found ()
  "Should return value in `mastodon-auth--token-alist' if found."
  (let ((mastodon-instance-url "https://instance.url")
        (mastodon-auth--token-alist '(("https://instance.url" . "foobar")) ))
    (should
     (string= (mastodon-auth--access-token) "foobar"))))

(ert-deftest mastodon-auth--access-token-not-found ()
  "Should set and return `mastodon-auth--token' if nil."
  (let ((mastodon-instance-url "https://instance.url")
        (mastodon-active-user "user")
        (mastodon-auth--token-alist nil))
    (with-mock
      (mock (mastodon-auth--get-token) => '(:access_token "foobaz"))
      (mock (mastodon-client--store-access-token "foobaz"))
      (stub mastodon-client--make-user-active)
      (should
       (string= (mastodon-auth--access-token)
                "foobaz"))
      (should
       (equal mastodon-auth--token-alist
              '(("https://instance.url" . "foobaz")))))))

(ert-deftest mastodon-auth--user-unaware ()
  (let ((mastodon-instance-url "https://instance.url")
        (mastodon-active-user nil)
        (mastodon-auth--token-alist nil))
    (with-mock
      (mock (mastodon-client--active-user))
      (should-error (mastodon-auth--access-token)))))
