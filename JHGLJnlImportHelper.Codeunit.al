codeunit 50111 "JH GL Journal Import Helper"
{
    Subtype = Normal;
    SingleInstance = true;

    var
        GlobalLineNo: Integer;
        GlobalTemplateName: Code[10];
        GlobalBatchName: Code[10];

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

        // Validate that at least one search criterion is provided
        if not ValidateSearchCriteria(SetupRec) then
            Error('At least one search criterion must be provided:\n- GL Search AcctId\n- GL Search BatchNum\n- GL Search BrCode\n- GL Search GLCostCtr\n- GL Search GLProdCode');

        Token := TokenService.GetToken();
        Token := Token.Trim();

        if Token.StartsWith('Bearer ') then
            Token := Token.Substring(8);

        SoapRequest := BuildGLHistSrchSoapRequest(SetupRec);

        RequestContent.WriteFrom(SoapRequest);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'text/xml; charset=utf-8');

        MakeAuthenticatedPostRequest(Client, SetupRec."Middleware URL", RequestContent, Token, Response);

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then begin
            Error('SOAP API call failed with status %1', Response.HttpStatusCode());
        end;

        ProcessXmlResponse(ResponseText);
    end;

    local procedure BuildGLHistSrchSoapRequest(SetupRec: Record "JH Integration Setup"): Text
    var
        XmlText: Text;
        JxLogTrackingId: Text;
        StartDtText: Text;
        EndDtText: Text;
        DefaultStartDate: Date;
        DefaultEndDate: Date;
    begin
        JxLogTrackingId := CreateGuid();

        // If no dates specified, default to last 90 days
        DefaultStartDate := CalcDate('<-90D>', Today());
        DefaultEndDate := Today();

        // Format dates as YYYY-MM-DD if they exist
        if SetupRec."GL Search Start Date" <> 0D then
            StartDtText := Format(SetupRec."GL Search Start Date", 0, '<Year4>-<Month,2>-<Day,2>')
        else
            StartDtText := Format(DefaultStartDate, 0, '<Year4>-<Month,2>-<Day,2>');

        if SetupRec."GL Search End Date" <> 0D then
            EndDtText := Format(SetupRec."GL Search End Date", 0, '<Year4>-<Month,2>-<Day,2>')
        else
            EndDtText := Format(DefaultEndDate, 0, '<Year4>-<Month,2>-<Day,2>');

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>';
        XmlText += '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ';
        XmlText += 'xmlns:xsd="http://www.w3.org/2001/XMLSchema" ';
        XmlText += 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">';
        XmlText += '<SOAP-ENV:Header></SOAP-ENV:Header>';
        XmlText += '<SOAP-ENV:Body>';
        XmlText += '<GLHistSrch xmlns="http://jackhenry.com/jxchange/TPG/2008">';
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
        
        // GL History Search specific parameters - use values from setup
        // At least ONE of these search criteria must be provided
        if SetupRec."GL Search AcctId" <> '' then
            XmlText += '<AcctId>' + SetupRec."GL Search AcctId" + '</AcctId>'
        else
            XmlText += '<AcctId/>';

        if SetupRec."GL Search BatchNum" <> '' then
            XmlText += '<BatchNum>' + SetupRec."GL Search BatchNum" + '</BatchNum>'
        else
            XmlText += '<BatchNum/>';

        if SetupRec."GL Search BrCode" <> '' then
            XmlText += '<BrCode>' + SetupRec."GL Search BrCode" + '</BrCode>'
        else
            XmlText += '<BrCode/>';

        if SetupRec."GL Search GLCostCtr" <> '' then
            XmlText += '<GLCostCtr>' + SetupRec."GL Search GLCostCtr" + '</GLCostCtr>'
        else
            XmlText += '<GLCostCtr/>';

        if SetupRec."GL Search GLProdCode" <> '' then
            XmlText += '<GLProdCode>' + SetupRec."GL Search GLProdCode" + '</GLProdCode>'
        else
            XmlText += '<GLProdCode/>';

        // Always include date range (defaults to last 90 days)
        XmlText += '<StartDt>' + StartDtText + '</StartDt>';
        XmlText += '<EndDt>' + EndDtText + '</EndDt>';

        if SetupRec."GL Search LowAmt" <> 0 then
            XmlText += '<LowAmt>' + Format(SetupRec."GL Search LowAmt", 0, 9) + '</LowAmt>'
        else
            XmlText += '<LowAmt/>';

        if SetupRec."GL Search HighAmt" <> 0 then
            XmlText += '<HighAmt>' + Format(SetupRec."GL Search HighAmt", 0, 9) + '</HighAmt>'
        else
            XmlText += '<HighAmt/>';

        if SetupRec."GL Search SrtMthd" <> '' then
            XmlText += '<SrtMthd>' + SetupRec."GL Search SrtMthd" + '</SrtMthd>'
        else
            XmlText += '<SrtMthd/>';

        if SetupRec."GL Search MemoPostInc" <> '' then
            XmlText += '<MemoPostInc>' + SetupRec."GL Search MemoPostInc" + '</MemoPostInc>'
        else
            XmlText += '<MemoPostInc/>';
        
        XmlText += '</GLHistSrch>';
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
        SetupRec: Record "JH Integration Setup";
    begin
        SuccessCount := 0;
        FirstRecordProcessed := false;

        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');

        // Initialize global variables for batch insert
        GlobalTemplateName := SetupRec."Journal Template";
        GlobalBatchName := SetupRec."Journal Batch";
        GlobalLineNo := GetNextLineNumber(GlobalTemplateName, GlobalBatchName);

        if not XmlDocument.ReadFrom(ResponseText, XmlDoc) then
            Error('Failed to parse XML response.');

        XmlDoc.GetRoot(Root);

        if not FindChildElementByLocalName(Root, 'Body', BodyElement) then
            Error('SOAP Body not found in response.');

        // Look for GLHistSrchResponse first (correct response element)
        if not FindChildElementByLocalName(BodyElement, 'GLHistSrchResponse', RespElement) then
            Error('GLHistSrchResponse element not found in SOAP Body.');

        // Check for errors in response header
        if FindChildElementByLocalName(RespElement, 'SrchMsgRsHdr', ErrorElement) then begin
            ErrCodeText := GetXmlElementValue(ErrorElement, 'MsgRecInfoArray/MsgRec/ErrCode');
            if ErrCodeText <> '' then begin
                ErrDesc := GetXmlElementValue(ErrorElement, 'MsgRecInfoArray/MsgRec/ErrDesc');
                Message('✓ Jack Henry API Response: %1 (Error Code: %2)', ErrDesc, ErrCodeText);
                exit;
            end;
        end;

        // Look for GLHistSrchRecArray (the correct array element for GL History records)
        if not FindChildElementByLocalName(RespElement, 'GLHistSrchRecArray', RecArrayElement) then begin
            Message('✓ No record array found in response. Dumping full response structure:');
            Message('✓ Full response (first 3000 chars):\n%1', CopyStr(ResponseText, 1, 3000));
            exit;
        end;

        ChildNodeList := RecArrayElement.GetChildNodes();

        // Process and insert each GL History record
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, RecNode);
            if RecNode.IsXmlElement() then begin
                TempNode := RecNode.AsXmlElement();
                if TempNode.LocalName() = 'GLHistSrchRec' then begin
                    if not FirstRecordProcessed then begin
                        FirstRecordProcessed := true;
                    end;

                    if ProcessAndInsertGLTransaction(RecNode) then
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

    local procedure ProcessAndInsertGLTransaction(RecNode: XmlNode): Boolean
    var
        GenJnlLine: Record "Gen. Journal Line";
        GLAccount: Record "G/L Account";
        Amount: Decimal;
        Description: Text[100];
        PostingDate: Date;
        AmountText, AcctTitle, AcctId : Text;
        EffDt: Date;
        TrnCodeCode: Code[20];
        DebitOrCredit: Code[10];
        TrnUsrId: Code[20];
        SeqNum: Code[20];
        MappedAccountNo: Code[20];
        BatchNum: Text;
        PostDt: Date;
    begin
        if not RecNode.IsXmlElement() then
            exit(false);

        // Extract GL History specific fields from GLHistSrchRec
        AcctId := GetXmlNodeValue(RecNode, 'AcctId');
        AcctTitle := GetXmlNodeValue(RecNode, 'AcctTitle');
        AmountText := GetXmlNodeValue(RecNode, 'Amt');
        EffDt := ConvertToDate(GetXmlNodeValue(RecNode, 'EffDt'));
        PostDt := ConvertToDate(GetXmlNodeValue(RecNode, 'PostDt'));
        TrnCodeCode := CopyStr(GetXmlNodeValue(RecNode, 'TrnCodeCode'), 1, 20);
        TrnUsrId := CopyStr(GetXmlNodeValue(RecNode, 'TrnUsrId'), 1, 20);
        SeqNum := CopyStr(GetXmlNodeValue(RecNode, 'SeqNum'), 1, 20);
        BatchNum := GetXmlNodeValue(RecNode, 'BatchNum');

        if not Evaluate(Amount, AmountText) then
            Amount := 0;

        Description := CopyStr(AcctTitle, 1, 100);
        if Description = '' then
            Description := 'GL Transaction';
            
        PostingDate := PostDt;
        if PostingDate = 0D then
            PostingDate := Today();

        if AcctId = '' then
            exit(false);

        // Try to find G/L Account with matching No.
        if GLAccount.Get(CopyStr(AcctId, 1, 20)) then begin
            MappedAccountNo := GLAccount."No.";
        end else begin
            // If not found, try to find G/L Account with matching No. 2
            GLAccount.Reset();
            GLAccount.SetFilter("No. 2", CopyStr(AcctId, 1, 20));
            if GLAccount.FindFirst() then begin
                MappedAccountNo := GLAccount."No.";
            end else begin
                // No match found - don't insert this line
                exit(false);
            end;
        end;

        // Prepare and insert journal line with mapped account
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GlobalTemplateName;
        GenJnlLine."Journal Batch Name" := GlobalBatchName;
        GenJnlLine."Line No." := GlobalLineNo;
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
        GenJnlLine.Validate("Account No.", MappedAccountNo);
        GenJnlLine.Amount := Amount;
        GenJnlLine.Description := Description;
        GenJnlLine."Posting Date" := PostingDate;
        GenJnlLine."Document Date" := EffDt;
        GenJnlLine."External Document No." := TrnCodeCode;
        GenJnlLine."Source Code" := TrnUsrId;

        // if SeqNum <> '' then
        //     GenJnlLine.lvnLoanNo := SeqNum;

        GenJnlLine.Insert(false);  // Insert without running triggers

        // Assign dimensions after the line is inserted
        // AssignDimensionsToJournalLine(GenJnlLine, RecNode);

        GlobalLineNo += 10000;
        exit(true);
    end;

    local procedure AssignDimensionsToJournalLine(var GenJnlLine: Record "Gen. Journal Line"; RecNode: XmlNode)
    var
        DimSetEntry: Record "Dimension Set Entry";
        DimMgt: Codeunit DimensionManagement;
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        BrCode: Text;
        GLCostCtr: Text;
        GLProdCode: Text;
        NewDimSetID: Integer;
        // DebugMsg: Text;
    begin
        // Check if we have a valid XML element
        if not RecNode.IsXmlElement() then
            exit;

        // Extract the dimension fields from GLHistSrchRec
        BrCode := GetXmlNodeValue(RecNode, 'BrCode');
        GLCostCtr := GetXmlNodeValue(RecNode, 'GLCostCtr');
        GLProdCode := GetXmlNodeValue(RecNode, 'GLProdCode');

        // DEBUG: Show extracted dimension values
        // DebugMsg := 'DEBUG - Extracted Dimensions:\n';
        // DebugMsg += 'BrCode: [' + BrCode + ']\n';
        // DebugMsg += 'GLCostCtr: [' + GLCostCtr + ']\n';
        // DebugMsg += 'GLProdCode: [' + GLProdCode + ']';
        // Message(DebugMsg);

        // Add BrCode dimension if present
        if BrCode <> '' then begin
            if AddDimensionToTempTable(TempDimSetEntry, 'BRANCH', CopyStr(BrCode, 1, 20)) then;
            //     Message('✓ BrCode dimension added: %1', BrCode)
            // else
            //     Message('✗ Failed to add BrCode dimension: %1', BrCode);
        end;

        // Add GLCostCtr dimension if present
        if GLCostCtr <> '' then begin
            if AddDimensionToTempTable(TempDimSetEntry, 'COSTCENTER', CopyStr(GLCostCtr, 1, 20)) then;
            //     Message('✓ GLCostCtr dimension added: %1', GLCostCtr)
            // else
            //     Message('✗ Failed to add GLCostCtr dimension: %1', GLCostCtr);
        end;

        // Add GLProdCode dimension if present
        if GLProdCode <> '' then begin
            if AddDimensionToTempTable(TempDimSetEntry, 'PRODUCT', CopyStr(GLProdCode, 1, 20)) then;
            //     Message('✓ GLProdCode dimension added: %1', GLProdCode)
            // else
            //     Message('✗ Failed to add GLProdCode dimension: %1', GLProdCode);
        end;

        // If we have any dimensions, create dimension set and assign to journal line
        if not TempDimSetEntry.IsEmpty then begin
            NewDimSetID := DimMgt.GetDimensionSetID(TempDimSetEntry);
            if NewDimSetID <> 0 then begin
                GenJnlLine."Dimension Set ID" := NewDimSetID;
                GenJnlLine.Modify(false);
                // Message('✓ Dimension Set ID %1 assigned to journal line', NewDimSetID);
            // end else begin
            //     Message('✗ Failed to create dimension set');
            end;
        // end else begin
        //     Message('✗ No dimensions were added to temporary table');
        end;
    end;

    local procedure AddDimensionToTempTable(var TempDimSetEntry: Record "Dimension Set Entry" temporary; DimCode: Code[20]; DimValueCode: Code[20]): Boolean
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
    begin
        if (DimCode = '') or (DimValueCode = '') then begin
            // Message('✗ Empty dimension code or value: DimCode=[%1], DimValueCode=[%2]', DimCode, DimValueCode);
            exit(false);
        end;

        // Check if dimension exists
        if not Dimension.Get(DimCode) then begin
            // Message('✗ Dimension code not found in BC: [%1]', DimCode);
            exit(false);
        end;

        // Check if dimension value exists
        DimensionValue.SetRange("Dimension Code", DimCode);
        DimensionValue.SetRange(Code, DimValueCode);
        if not DimensionValue.FindFirst() then begin
            // Message('✗ Dimension value not found in BC: DimCode=[%1], ValueCode=[%2]', DimCode, DimValueCode);
            exit(false);
        end;

        TempDimSetEntry.Init();
        TempDimSetEntry."Dimension Code" := DimCode;
        TempDimSetEntry."Dimension Value Code" := DimValueCode;
        if not TempDimSetEntry.Insert() then begin
            // Message('✗ Failed to insert dimension into temp table: DimCode=[%1], ValueCode=[%2]', DimCode, DimValueCode);
            exit(false);
        end;

        exit(true);
    end;

    local procedure ValidateDimension(DimCode: Code[20]; DimValueCode: Code[20]): Boolean
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
    begin
        // Check if dimension exists
        if not Dimension.Get(DimCode) then
            exit(false);

        // Check if dimension value exists
        DimensionValue.SetRange("Dimension Code", DimCode);
        DimensionValue.SetRange(Code, DimValueCode);
        if not DimensionValue.FindFirst() then
            exit(false);

        exit(true);
    end;

    local procedure GetNextLineNumber(TemplateName: Code[10]; BatchName: Code[10]): Integer
    var
        GenJnlLine: Record "Gen. Journal Line";
    begin
        GenJnlLine.SetRange("Journal Template Name", TemplateName);
        GenJnlLine.SetRange("Journal Batch Name", BatchName);

        if GenJnlLine.FindLast() then
            exit(GenJnlLine."Line No." + 10000);

        exit(10000);
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

    local procedure GetXmlNodeValueFromElement(ParentElement: XmlElement; NodeName: Text): Text
    var
        ChildNodeList: XmlNodeList;
        i: Integer;
        TempNode: XmlNode;
        TempElement: XmlElement;
        ResultText: Text;
    begin
        ChildNodeList := ParentElement.GetChildNodes();
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, TempNode);
            if TempNode.IsXmlElement() then begin
                TempElement := TempNode.AsXmlElement();
                if TempElement.LocalName() = NodeName then begin
                    ResultText := TempElement.InnerText();
                    while (ResultText <> '') and not (ResultText[StrLen(ResultText)] in ['0'..'9']) do
                        ResultText := CopyStr(ResultText, 1, StrLen(ResultText) - 1);
                    exit(ResultText);
                end;
            end;
        end;
        exit('');
    end;

    local procedure ConvertToDate(DateText: Text): Date
    var
        ResultDate: Date;
    begin
        if DateText = '' then
            exit(Today());

        if not Evaluate(ResultDate, DateText) then
            ResultDate := Today();

        exit(ResultDate);
    end;

    local procedure GetFirstRecordDebug(RecNode: XmlNode): Text
    var
        AcctId, Amt, AcctTitle, EffDt, PostDt, TrnCodeCode, TrnUsrId, SeqNum, BatchNum, BrCode, GLCostCtr, GLProdCode, Result : Text;
    begin
        AcctId := GetXmlNodeValue(RecNode, 'AcctId');
        Amt := GetXmlNodeValue(RecNode, 'Amt');
        AcctTitle := GetXmlNodeValue(RecNode, 'AcctTitle');
        EffDt := GetXmlNodeValue(RecNode, 'EffDt');
        PostDt := GetXmlNodeValue(RecNode, 'PostDt');
        TrnCodeCode := GetXmlNodeValue(RecNode, 'TrnCodeCode');
        TrnUsrId := GetXmlNodeValue(RecNode, 'TrnUsrId');
        SeqNum := GetXmlNodeValue(RecNode, 'SeqNum');
        BatchNum := GetXmlNodeValue(RecNode, 'BatchNum');
        BrCode := GetXmlNodeValue(RecNode, 'BrCode');
        GLCostCtr := GetXmlNodeValue(RecNode, 'GLCostCtr');
        GLProdCode := GetXmlNodeValue(RecNode, 'GLProdCode');

        Result := 'AcctId: [' + AcctId + ']' + '\n';
        Result += 'Amt: [' + Amt + ']' + '\n';
        Result += 'AcctTitle: [' + AcctTitle + ']' + '\n';
        Result += 'EffDt: [' + EffDt + ']' + '\n';
        Result += 'PostDt: [' + PostDt + ']' + '\n';
        Result += 'TrnCodeCode: [' + TrnCodeCode + ']' + '\n';
        Result += 'TrnUsrId: [' + TrnUsrId + ']' + '\n';
        Result += 'SeqNum: [' + SeqNum + ']' + '\n';
        Result += 'BatchNum: [' + BatchNum + ']' + '\n';
        Result += 'BrCode: [' + BrCode + ']' + '\n';
        Result += 'GLCostCtr: [' + GLCostCtr + ']' + '\n';
        Result += 'GLProdCode: [' + GLProdCode + ']';

        exit(Result);
    end;

    local procedure GetAllXmlElements(RecNode: XmlNode): Text
    var
        ChildNodeList: XmlNodeList;
        i: Integer;
        TempNode: XmlNode;
        TempElement: XmlElement;
        Result: Text;
    begin
        Result := '';
        if RecNode.IsXmlElement() then begin
            ChildNodeList := RecNode.AsXmlElement().GetChildNodes();
            for i := 1 to ChildNodeList.Count() do begin
                ChildNodeList.Get(i, TempNode);
                if TempNode.IsXmlElement() then begin
                    TempElement := TempNode.AsXmlElement();
                    Result += TempElement.LocalName() + ' = [' + TempElement.InnerText() + ']\n';
                end;
            end;
        end;
        exit(Result);
    end;

    local procedure PostJournalBatch()
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPostBatch: Codeunit "Gen. Jnl.-Post Batch";
        SetupRec: Record "JH Integration Setup";
        BatchName: Code[10];
        TemplateName: Code[10];
    begin
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');

        TemplateName := SetupRec."Journal Template";
        BatchName := SetupRec."Journal Batch";

        if TemplateName = '' then
            Error('Journal Template is not configured in JH Integration Setup.');
        if BatchName = '' then
            Error('Journal Batch is not configured in JH Integration Setup.');

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

    procedure ValidateSearchCriteria(SetupRec: Record "JH Integration Setup"): Boolean
    begin
        // At least ONE search criterion must be provided for GLHistSrch
        exit((SetupRec."GL Search AcctId" <> '') or
             (SetupRec."GL Search BatchNum" <> '') or
             (SetupRec."GL Search BrCode" <> '') or
             (SetupRec."GL Search GLCostCtr" <> '') or
             (SetupRec."GL Search GLProdCode" <> ''));
    end;

    // DISCOVERY API HELPERS - Use these to explore available values in production
    
    procedure CallParmValSrch(ParmName: Text): Text
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
        // ParmValSrch - Parameter Value Search
        // Used to discover valid parameter values for specific fields
        
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');

        Token := TokenService.GetToken();
        Token := Token.Trim();
        if Token.StartsWith('Bearer ') then
            Token := Token.Substring(8);

        SoapRequest := BuildParmValSrchRequest(SetupRec, ParmName);
        
        RequestContent.WriteFrom(SoapRequest);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'text/xml; charset=utf-8');

        Client.DefaultRequestHeaders.Clear();
        Client.DefaultRequestHeaders.Add('SOAPAction', 'http://jackhenry.com/ws/ParmValSrch');
        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token);

        if not Client.Post(SetupRec."Middleware URL", RequestContent, Response) then
            Error('Failed to call ParmValSrch');

        Response.Content().ReadAs(ResponseText);
        exit(ResponseText);
    end;

    procedure CallSvcDictSrch(): Text
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
        // SvcDictSrch - Service Dictionary Search
        // Used to discover available services and their structures
        
        if not GetSetupRecord(SetupRec) then
            Error('JH Integration Setup record not found.');

        Token := TokenService.GetToken();
        Token := Token.Trim();
        if Token.StartsWith('Bearer ') then
            Token := Token.Substring(8);

        SoapRequest := BuildSvcDictSrchRequest(SetupRec);
        
        RequestContent.WriteFrom(SoapRequest);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'text/xml; charset=utf-8');

        Client.DefaultRequestHeaders.Clear();
        Client.DefaultRequestHeaders.Add('SOAPAction', 'http://jackhenry.com/ws/SvcDictSrch');
        Client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + Token);

        if not Client.Post(SetupRec."Middleware URL", RequestContent, Response) then
            Error('Failed to call SvcDictSrch');

        Response.Content().ReadAs(ResponseText);
        exit(ResponseText);
    end;

    local procedure BuildParmValSrchRequest(SetupRec: Record "JH Integration Setup"; ParmName: Text): Text
    var
        XmlText: Text;
        JxLogTrackingId: Text;
    begin
        JxLogTrackingId := CreateGuid();

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>';
        XmlText += '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">';
        XmlText += '<SOAP-ENV:Header></SOAP-ENV:Header>';
        XmlText += '<SOAP-ENV:Body>';
        XmlText += '<ParmValSrch xmlns="http://jackhenry.com/jxchange/TPG/2008">';
        XmlText += '<SrchMsgRqHdr>';
        XmlText += '<jXchangeHdr>';
        XmlText += '<ConsumerName>' + SetupRec."ValidConsmName" + '</ConsumerName>';
        XmlText += '<ConsumerProd>' + SetupRec."ValidConsmProd" + '</ConsumerProd>';
        XmlText += '<jXLogTrackingId>' + JxLogTrackingId + '</jXLogTrackingId>';
        XmlText += '<InstRtId>' + SetupRec."InstRtId" + '</InstRtId>';
        XmlText += '<InstEnv>' + SetupRec."InstEnv" + '</InstEnv>';
        XmlText += '<ValidConsmName>' + SetupRec."ValidConsmName" + '</ValidConsmName>';
        XmlText += '<ValidConsmProd>' + SetupRec."ValidConsmProd" + '</ValidConsmProd>';
        XmlText += '</jXchangeHdr>';
        XmlText += '<MaxRec>100</MaxRec>';
        XmlText += '</SrchMsgRqHdr>';
        XmlText += '<ParmName>' + ParmName + '</ParmName>';
        XmlText += '</ParmValSrch>';
        XmlText += '</SOAP-ENV:Body>';
        XmlText += '</SOAP-ENV:Envelope>';

        exit(XmlText);
    end;

    local procedure BuildSvcDictSrchRequest(SetupRec: Record "JH Integration Setup"): Text
    var
        XmlText: Text;
        JxLogTrackingId: Text;
    begin
        JxLogTrackingId := CreateGuid();

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>';
        XmlText += '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">';
        XmlText += '<SOAP-ENV:Header></SOAP-ENV:Header>';
        XmlText += '<SOAP-ENV:Body>';
        XmlText += '<SvcDictSrch xmlns="http://jackhenry.com/jxchange/TPG/2008">';
        XmlText += '<SrchMsgRqHdr>';
        XmlText += '<jXchangeHdr>';
        XmlText += '<ConsumerName>' + SetupRec."ValidConsmName" + '</ConsumerName>';
        XmlText += '<ConsumerProd>' + SetupRec."ValidConsmProd" + '</ConsumerProd>';
        XmlText += '<jXLogTrackingId>' + JxLogTrackingId + '</jXLogTrackingId>';
        XmlText += '<InstRtId>' + SetupRec."InstRtId" + '</InstRtId>';
        XmlText += '<InstEnv>' + SetupRec."InstEnv" + '</InstEnv>';
        XmlText += '<ValidConsmName>' + SetupRec."ValidConsmName" + '</ValidConsmName>';
        XmlText += '<ValidConsmProd>' + SetupRec."ValidConsmProd" + '</ValidConsmProd>';
        XmlText += '</jXchangeHdr>';
        XmlText += '<MaxRec>100</MaxRec>';
        XmlText += '</SrchMsgRqHdr>';
        XmlText += '<SvcName>GLHistSrch</SvcName>';
        XmlText += '</SvcDictSrch>';
        XmlText += '</SOAP-ENV:Body>';
        XmlText += '</SOAP-ENV:Envelope>';

        exit(XmlText);
    end;
}