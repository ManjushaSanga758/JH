page 50102 "JH Parameter Discovery"
{
    PageType = List;
    Caption = 'Jack Henry Parameter Discovery';
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                    ToolTip = 'Parameter value code';
                }
                field(Value; Rec.Value)
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    ToolTip = 'Parameter value description';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(DiscoverBrCode)
            {
                Caption = 'Discover Branch Codes';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Get all valid branch codes from Jack Henry';

                trigger OnAction()
                begin
                    DiscoverParameter('BrCode');
                end;
            }

            action(DiscoverGLCostCtr)
            {
                Caption = 'Discover Cost Centers';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Get all valid cost centers from Jack Henry';

                trigger OnAction()
                begin
                    DiscoverParameter('GLCostCtr');
                end;
            }

            action(DiscoverGLProdCode)
            {
                Caption = 'Discover Product Codes';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Get all valid product codes from Jack Henry';

                trigger OnAction()
                begin
                    DiscoverParameter('GLProdCode');
                end;
            }

            action(DiscoverCustom)
            {
                Caption = 'Discover Custom Parameter';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Enter a custom parameter name to discover';

                trigger OnAction()
                begin
                    Message('Use the specific buttons above to discover:\n\n- Branch Codes (BrCode)\n- Cost Centers (GLCostCtr)\n- Product Codes (GLProdCode)\n\nContact your administrator to add other custom parameters.');
                end;
            }
        }
    }

    local procedure DiscoverParameter(ParmName: Text)
    var
        JHHelper: Codeunit "JH GL Journal Import Helper";
        ResponseText: Text;
        XmlDoc: XmlDocument;
        Root: XmlElement;
        BodyElement: XmlElement;
        ResponseElement: XmlElement;
        RecArrayElement: XmlElement;
        RecNode: XmlNode;
        RecElement: XmlElement;
        ChildNodeList: XmlNodeList;
        i: Integer;
        Code: Text;
        Description: Text;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        ResponseText := JHHelper.CallParmValSrch(ParmName);

        if not XmlDocument.ReadFrom(ResponseText, XmlDoc) then begin
            Message('Failed to parse response XML');
            exit;
        end;

        XmlDoc.GetRoot(Root);

        // Navigate: Envelope -> Body -> ParmValSrchResponse -> ParmValSrchRecArray
        if not FindChildElement(Root, 'Body', BodyElement) then begin
            Message('Body element not found');
            exit;
        end;

        if not FindChildElement(BodyElement, 'ParmValSrchResponse', ResponseElement) then begin
            Message('ParmValSrchResponse element not found');
            exit;
        end;

        if not FindChildElement(ResponseElement, 'ParmValSrchRecArray', RecArrayElement) then begin
            Message('No records found for parameter: %1', ParmName);
            exit;
        end;

        ChildNodeList := RecArrayElement.GetChildNodes();
        
        for i := 1 to ChildNodeList.Count() do begin
            ChildNodeList.Get(i, RecNode);
            if RecNode.IsXmlElement() then begin
                RecElement := RecNode.AsXmlElement();
                if RecElement.LocalName() = 'ParmValSrchRec' then begin
                    Code := GetChildElementValue(RecElement, 'ParmValCode');
                    Description := GetChildElementValue(RecElement, 'ParmValDesc');
                    
                    if Code <> '' then begin
                        Rec.Init();
                        Rec.ID := Rec.ID + 1;
                        Rec.Name := CopyStr(Code, 1, MaxStrLen(Rec.Name));
                        Rec.Value := CopyStr(Description, 1, MaxStrLen(Rec.Value));
                        Rec.Insert();
                    end;
                end;
            end;
        end;

        if Rec.Count = 0 then
            Message('No values found for parameter: %1', ParmName)
        else
            Message('Found %1 values for parameter: %2', Rec.Count, ParmName);

        CurrPage.Update(false);
    end;

    local procedure FindChildElement(ParentElement: XmlElement; LocalName: Text; var FoundElement: XmlElement): Boolean
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

    local procedure GetChildElementValue(ParentElement: XmlElement; LocalName: Text): Text
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
                if TempElement.LocalName() = LocalName then
                    exit(TempElement.InnerText());
            end;
        end;
        exit('');
    end;
}