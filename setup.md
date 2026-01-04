
openssl pkcs12 -export -in fullchain.pem -inkey server.key -out server.p12 \                                                                                                    (base)
        -name wso2carbon -CAfile ca.crt -caname "WSO2 Local CA" -chain
    -password pass:"wso2carbon"


openssl pkcs12 -in server.p12 -nodes -passin pass:wso2carbon | grep -E "subject=|issuer="                                                                                       (base)
subject=C=US, ST=CA, L=Mountain View, O=WSO2, OU=WSO2, CN=*.local
issuer=C=US, ST=CA, L=Mountain View, O=WSO2, OU=WSO2, CN=WSO2 Local CA
subject=C=US, ST=CA, L=Mountain View, O=WSO2, OU=WSO2, CN=WSO2 Local CA
issuer=C=US, ST=CA, L=Mountain View, O=WSO2, OU=WSO2, CN=WSO2 Local CA
