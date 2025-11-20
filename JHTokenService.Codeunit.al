codeunit 50110 "JH Token Service"
{
    SingleInstance = true;

    procedure GetToken(): Text
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        RequestContent: HttpContent;
        RequestJson: Text;
        ResponseJson: Text;
        JObject: JsonObject;
        TokenValue: JsonToken;
        Setup: Record "JH Integration Setup";
        ContentHeaders: HttpHeaders;
        FunctionUrl: Text;
        Token: Text;
    begin
        // Get setup configuration
        Setup.Reset();
        if not Setup.FindFirst() then
            Error('Jack Henry Integration Setup not configured. Please configure it from the JH Integration Setup page.');

        // Validate required fields
        if Setup.TokenBrokerUrl = '' then
            Error('Token Broker URL is not configured in JH Integration Setup.');

        if Setup."Client ID" = '' then
            Error('Jack Henry Client ID is not configured in JH Integration Setup.');

        if Setup.PrivateKey = '' then
            Error('Private Key is not configured in JH Integration Setup.');

        // Build request JSON for your Function App
        RequestJson := BuildTokenRequest(Setup);

        // Set up HTTP content
        RequestContent.WriteFrom(RequestJson);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        // Add function key to URL if provided
        if Setup.FunctionKey <> '' then
            FunctionUrl := Setup.TokenBrokerUrl + '?code=' + Setup.FunctionKey
        else
            FunctionUrl := Setup.TokenBrokerUrl;

        // Clear client headers
        Client.DefaultRequestHeaders.Clear();

        // Call Token Broker Function App
        if not Client.Post(FunctionUrl, RequestContent, Response) then
            Error('Failed to connect to Token Broker at %1', FunctionUrl);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseJson);
            Error('Token Broker returned error. Status: %1, Response: %2', Response.HttpStatusCode(), ResponseJson);
        end;

        // Read response
        Response.Content().ReadAs(ResponseJson);

        if ResponseJson = '' then
            Error('Token Broker returned empty response.');

        // Parse JSON response
        if not JObject.ReadFrom(ResponseJson) then
            Error('Failed to parse Token Broker response as JSON. Response: %1', ResponseJson);

        // Extract access token
        if JObject.Get('access_token', TokenValue) then begin
            Token := TokenValue.AsValue().AsText();
            Token := Token.Trim();
            Token := RemoveInvalidChars(Token);
            
            if Token = '' then
                Error('Token is empty after cleaning.');
            
            exit(Token);
        end else
            Error('Access token not found in response. Response: %1', ResponseJson);
    end;

    local procedure RemoveInvalidChars(InputText: Text): Text
    var
        Result: Text;
        i: Integer;
        Char: Char;
    begin
        Result := '';
        for i := 1 to StrLen(InputText) do begin
            Char := InputText[i];
            if (Char >= ' ') and (Char <> '"') then
                Result += Format(Char);
        end;
        exit(Result);
    end;

    local procedure BuildTokenRequest(Setup: Record "JH Integration Setup"): Text
    var
        JObject: JsonObject;
        RequestText: Text;
    begin
        JObject.Add('clientId', Setup."Client ID");
        JObject.Add('privateKey', Setup.PrivateKey);
        JObject.Add('scope', Setup.Scope);

        JObject.WriteTo(RequestText);
        exit(RequestText);
    end;
}