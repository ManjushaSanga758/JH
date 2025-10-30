codeunit 50111 "JH GL Journal Import Helper"
{
    Subtype = Normal;
    SingleInstance = true;

    procedure ImportAndPostJournalEntries()
    var
        ConfirmRes: Boolean;
    begin
        ConfirmRes := Confirm('This will:\n1. Get GL entries from Jack Henry via SOAP\n2. Create journal lines in BC\n3. Post the journals\n\nDo you want to continue?', false);
        if not ConfirmRes then
            exit;

        TaskScheduler.CreateTask(Codeunit::"JH GL Journal Import Helper", 0, true, CompanyName(), CurrentDateTime() + 1000);
        Message('✓ Import job queued. The journal entries will be imported and you will see results shortly.');
    end;

    trigger OnRun()
    var
        ConfirmRes: Boolean;
    begin
        ImportJournalEntries();

        ConfirmRes := Confirm('Journal entries imported successfully.\n\nDo you want to post them now?', true);
        if not ConfirmRes then
            exit;

        PostJournalBatch();
    end;

    procedure ImportJournalEntries()
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        RequestContent: HttpContent;
        SoapRequest: Text;
        ResponseText: Text;
        TokenService: Codeunit "JH Token Service";
        Token: Text;
        SetupRec: Record "JH Integration Setup";
        ContentHeaders: HttpHeaders;
    begin
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');

        Token := TokenService.GetToken();
        Token := Token.Trim();

        if Token.StartsWith('Bearer ') then
            Token := Token.Substring(8);

        Message('✓ Token received. Length: %1 characters', StrLen(Token));

        SoapRequest := BuildGLHistSrchSoapRequest(SetupRec);

        // Debug: Show the SOAP request
        Message('DEBUG - SOAP Request (first 2000 chars):\n%1', CopyStr(SoapRequest, 1, 2000));

        RequestContent.WriteFrom(SoapRequest);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'text/xml; charset=utf-8');

        Message('✓ Calling Jack Henry SOAP API');

        MakeAuthenticatedPostRequest(Client, SetupRec."Middleware URL", RequestContent, Token, Response);

        Response.Content().ReadAs(ResponseText);
        Message('✓ Response received. Status: %1', Response.HttpStatusCode());

        if not Response.IsSuccessStatusCode() then
            Error('SOAP API call failed with status %1', Response.HttpStatusCode());

        ProcessXmlResponse(ResponseText);
    end;

    local procedure BuildGLHistSrchSoapRequest(SetupRec: Record "JH Integration Setup"): Text
    var
        XmlText: Text;
        JxLogTrackingId : Text;
    begin
        JxLogTrackingId := CreateGuid();

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>';
        XmlText += '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ';
        XmlText += 'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ';
        XmlText += 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';
        XmlText += '<SOAP-ENV:Header></SOAP-ENV:Header>';
        XmlText += '<SOAP-ENV:Body>';
        XmlText += '<AcctSrch xmlns="http://jackhenry.com/jxchange/TPG/2008">';
        XmlText += '<SrchMsgRqHdr>';
        XmlText += '<jXchangeHdr>';
        XmlText += '<JxVer/>';
        XmlText += '<AuditUsrId>BCIntegration</AuditUsrId>';
        XmlText += '<AuditWsId>BC</AuditWsId>';
        XmlText += '<AuthenUsrId/>';
        XmlText += '<ConsumerName>' + SetupRec."ValidConsmName" + '</ConsumerName>';
        XmlText += '<ConsumerProd>' + SetupRec."ValidConsmProd" + '</ConsumerProd>';
        XmlText += '<Ver_1/>';
        XmlText += '<jXLogTrackingId>' + JxLogTrackingId + '</jXLogTrackingId>';
        XmlText += '<Ver_2/>';
        XmlText += '<InstRtId>' + SetupRec."InstRtId" + '</InstRtId>';
        XmlText += '<InstEnv>' + SetupRec."InstEnv" + '</InstEnv>';
        XmlText += '<Ver_3/>';
        XmlText += '<BusCorrelId/>';
        XmlText += '<Ver_4/>';
        XmlText += '<WorkflowCorrelId/>';
        XmlText += '<Ver_5/>';
        XmlText += '<ValidConsmName>' + SetupRec."ValidConsmName" + '</ValidConsmName>';
        XmlText += '<ValidConsmProd>' + SetupRec."ValidConsmProd" + '</ValidConsmProd>';
        XmlText += '<Ver_6/>';
        XmlText += '</jXchangeHdr>';
        XmlText += '<MaxRec>100</MaxRec>';
        XmlText += '<Cursor/>';
        XmlText += '<Ver_1/>';
        XmlText += '<Ver_2/>';
        XmlText += '<Ver_3/>';
        XmlText += '</SrchMsgRqHdr>';
        XmlText += '<CustId/>';
        XmlText += '<AcctType/>';
        XmlText += '<Ver_1/>';
        XmlText += '<PersonName>';
        XmlText += '<LastName>Smith</LastName>';
        XmlText += '<Ver_1/>';
        XmlText += '</PersonName>';
        XmlText += '<Ver_2/>';
        XmlText += '<Ver_3/>';
        XmlText += '<Ver_4/>';
        XmlText += '</AcctSrch>';
        XmlText += '</SOAP-ENV:Body>';
        XmlText += '</SOAP-ENV:Envelope>';

        exit(XmlText);
    end;

    local procedure ProcessXmlResponse(ResponseText: Text)
    var
        XmlDoc: XmlDocument;
        Root: XmlElement;
        BodyElement, RespElement, RecArrayElement, ErrorElement : XmlElement;
        i, SuccessCount : Integer;
        RecNode: XmlNode;
        TempNode: XmlElement;
        ErrCodeText, ErrDesc : Text;
        ChildNodeList: XmlNodeList;
        FirstRecordProcessed: Boolean;
    begin
        SuccessCount := 0;
        FirstRecordProcessed := false;

        if not XmlDocument.ReadFrom(ResponseText, XmlDoc) then
            Error('Failed to parse XML response.');

        XmlDoc.GetRoot(Root);

        if not FindChildElementByLocalName(Root, 'Body', BodyElement) then
            Error('SOAP Body not found in response.');

        // Try multiple response element types
        if not FindChildElementByLocalName(BodyElement, 'GLHistSrchResponse', RespElement) then
            if not FindChildElementByLocalName(BodyElement, 'GLHistSrch', RespElement) then
                if not FindChildElementByLocalName(BodyElement, 'AcctSrchResponse', RespElement) then
                    if not FindChildElementByLocalName(BodyElement, 'AcctSrch', RespElement) then begin
                        Error('Expected response element not found in SOAP Body.');
                    end;

        // Check for errors in response header
        if FindChildElementByLocalName(RespElement, 'SrchMsgRsHdr', ErrorElement) then begin
            ErrCodeText := GetXmlElementValue(ErrorElement, 'MsgRecInfoArray/MsgRec/ErrCode');
            if ErrCodeText <> '' then begin
                ErrDesc := GetXmlElementValue(ErrorElement, 'MsgRecInfoArray/MsgRec/ErrDesc');
                Message('✓ Jack Henry API Response: %1 (Error Code: %2)', ErrDesc, ErrCodeText);
                exit;
            end;
        end;

        // Look for record array - try multiple names
        if not FindChildElementByLocalName(RespElement, 'GLHistSrchRecArray', RecArrayElement) then
            if not FindChildElementByLocalName(RespElement, 'AcctSrchRecArray', RecArrayElement) then begin
                Message('✓ No record array found in response.');
                exit;
            end;

        // Process records directly by iterating through all children
        ChildNodeList := RecArrayElement.GetChildNodes();

        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, RecNode);
            if RecNode.IsXmlElement() then begin
                TempNode := RecNode.AsXmlElement();
                if (TempNode.LocalName() = 'GLHistSrchRec') or 
                   (TempNode.LocalName() = 'AcctSrchRec') then begin
                    // Show first record details
                    if not FirstRecordProcessed then begin
                        Message('DEBUG - First record:\n%1', GetFirstRecordDebug(RecNode));
                        FirstRecordProcessed := true;
                    end;
                    
                    if ProcessGLTransaction(RecNode) then
                        SuccessCount := SuccessCount + 1;
                end;
            end;
        end;

        Message('✓ Successfully imported %1 transactions from Jack Henry.', SuccessCount);
    end;

    local procedure FindChildElementByLocalName(ParentElement: XmlElement; LocalName: Text; var FoundElement: XmlElement): Boolean
    var
        ChildNodeList: XmlNodeList;
        i: Integer;
        TempNode: XmlNode;
        TempElement: XmlElement;
    begin
        ChildNodeList := ParentElement.GetChildNodes();
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, TempNode);
            if TempNode.IsXmlElement() then begin
                TempElement := TempNode.AsXmlElement();
                if TempElement.LocalName() = LocalName then begin
                    FoundElement := TempElement;
                    exit(true);
                end;
            end;
        end;
        exit(false);
    end;

    local procedure GetXmlElementValue(ParentElement: XmlElement; ElementPath: Text): Text
    var
        Child: XmlNode;
    begin
        if ParentElement.SelectSingleNode(ElementPath, Child) then
            exit(Child.AsXmlElement().InnerText());
        exit('');
    end;

    local procedure DumpXmlElementChildren(ParentElement: XmlElement)
    var
        ChildNodeList: XmlNodeList;
        i: Integer;
        TempNode: XmlNode;
        TempElement: XmlElement;
        DebugMsg: Text;
    begin
        ChildNodeList := ParentElement.GetChildNodes();
        DebugMsg := 'Child elements: ';
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, TempNode);
            if TempNode.IsXmlElement() then begin
                TempElement := TempNode.AsXmlElement();
                DebugMsg += TempElement.LocalName() + ', ';
            end;
        end;
        Message(DebugMsg);
    end;

    local procedure ProcessGLTransaction(RecNode: XmlNode): Boolean
    var
        AccountNo: Code[20];
        Amount: Decimal;
        Description: Text[100];
        PostingDate: Date;
        AmountText, CustomerName, AcctId : Text;
    begin
        AcctId := GetXmlNodeValue(RecNode, 'AccountId');
        CustomerName := GetXmlNodeValue(RecNode, 'PersonName');
        AmountText := GetXmlNodeValue(RecNode, 'Amt');
        
        if not Evaluate(Amount, AmountText) then
            Amount := 0;

        Description := CopyStr(CustomerName, 1, 100);
        PostingDate := Today();

        if (AcctId <> '') then begin
            InsertJournalLine(AcctId, Amount, Description, PostingDate);
            exit(true);
        end;

        exit(false);
    end;

    local procedure GetXmlNodeValue(ParentNode: XmlNode; NodeName: Text): Text
    var
        ChildNodeList: XmlNodeList;
        i: Integer;
        TempNode: XmlNode;
        TempElement: XmlElement;
    begin
        if not ParentNode.IsXmlElement() then
            exit('');
        
        ChildNodeList := ParentNode.AsXmlElement().GetChildNodes();
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, TempNode);
            if TempNode.IsXmlElement() then begin
                TempElement := TempNode.AsXmlElement();
                if TempElement.LocalName() = NodeName then
                    exit(TempElement.InnerText());
            end;
        end;
        exit('');
    end;

    local procedure GetFirstRecordDebug(RecNode: XmlNode): Text
    var
        AcctId, Amt, PersonName, Result: Text;
    begin
        AcctId := GetXmlNodeValue(RecNode, 'AccountId');
        Amt := GetXmlNodeValue(RecNode, 'Amt');
        PersonName := GetXmlNodeValue(RecNode, 'PersonName');
        
        Result := 'AccountId: [' + AcctId + ']' + '\n';
        Result += 'Amt: [' + Amt + ']' + '\n';
        Result += 'PersonName: [' + PersonName + ']';
        
        exit(Result);
    end;

    local procedure InsertJournalLine(AccountNo: Code[20]; Amount: Decimal; Description: Text[100]; PostingDate: Date)
    var
        GenJnlLine: Record "Gen. Journal Line";
        SetupRec: Record "JH Integration Setup";
        LineNo: Integer;
        BatchName: Code[10];
        TemplateName: Code[10];
    begin
        // Get batch name from setup
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');
        
        TemplateName := SetupRec."Journal Template";
        BatchName := SetupRec."Journal Batch";
        
        if TemplateName = '' then
            TemplateName := 'GENERAL';
        if BatchName = '' then
            BatchName := 'JACKHENRY';

        GenJnlLine.SetRange("Journal Template Name", TemplateName);
        GenJnlLine.SetRange("Journal Batch Name", BatchName);

        if GenJnlLine.FindLast() then
            LineNo := GenJnlLine."Line No." + 10000
        else
            LineNo := 10000;

        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := TemplateName;
        GenJnlLine."Journal Batch Name" := BatchName;
        GenJnlLine."Line No." := LineNo;
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
        GenJnlLine."Account No." := AccountNo;
        GenJnlLine.Amount := Amount;
        GenJnlLine.Description := Description;
        GenJnlLine."Posting Date" := PostingDate;
        GenJnlLine.Insert(true);
    end;

    local procedure PostJournalBatch()
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPostBatch: Codeunit "Gen. Jnl.-Post Batch";
        SetupRec: Record "JH Integration Setup";
        BatchName: Code[10];
        TemplateName: Code[10];
    begin
        // Get batch name from setup
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');
        
        TemplateName := SetupRec."Journal Template";
        BatchName := SetupRec."Journal Batch";
        
        if TemplateName = '' then
            TemplateName := 'GENERAL';
        if BatchName = '' then
            BatchName := 'JACKHENRY';

        GenJnlLine.SetRange("Journal Template Name", TemplateName);
        GenJnlLine.SetRange("Journal Batch Name", BatchName);

        if not GenJnlLine.FindFirst() then
            Error('No journal lines found to post.');

        GenJnlPostBatch.Run(GenJnlLine);
        Message('✓ Journal batch posted successfully!');
    end;

    local procedure GetSetupRecord(var SetupRec: Record "JH Integration Setup"): Boolean
    begin
        if not SetupRec.FindFirst() then
            exit(false);
        exit(true);
    end;

    local procedure MakeAuthenticatedPostRequest(var Client: HttpClient;
    Url: Text; Content: HttpContent; Token: Text; var Response: HttpResponseMessage)
    begin
        Client.DefaultRequestHeaders.Clear();
        Client.DefaultRequestHeaders.Add('SOAPAction', 'http://jackhenry.com/ws/GLHistSrch');
        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token.Trim());

        if not Client.Post(Url, Content, Response) then
            Error('Failed to connect to %1', Url);
    end;
}