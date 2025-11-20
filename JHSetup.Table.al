table 50101 "JH Integration Setup"
{
    DataClassification = ToBeClassified;
    Caption = 'Jack Henry Integration Setup';

    fields
    {
        field(1; "AzureTenantId"; Text[50])
        {
            Caption = 'Azure Tenant ID';
            DataClassification = CustomerContent;
        }

        field(2; "BC Client Id"; Text[100])
        {
            Caption = 'BC Client ID';
            DataClassification = CustomerContent;
        }

        field(3; "BC Client Secret"; Text[200])
        {
            Caption = 'BC Client Secret';
            DataClassification = CustomerContent;
        }

        field(4; "Function App Audience"; Text[200])
        {
            Caption = 'Function App Audience';
            DataClassification = CustomerContent;
        }

        field(5; TokenBrokerUrl; Text[250])
        {
            Caption = 'Token Broker URL';
            DataClassification = CustomerContent;
        }

        field(6; "Middleware URL"; Text[250])
        {
            Caption = 'Jack Henry SOAP URL (if using SOAP)';
            DataClassification = CustomerContent;
        }

        field(7; "Client ID"; Text[100])
        {
            Caption = 'Jack Henry Client ID';
            DataClassification = CustomerContent;
        }

        field(8; "Scope"; Text[250])
        {
            Caption = 'Jack Henry Scope';
            DataClassification = CustomerContent;
        }

        field(9; "PrivateKey"; Text[2048])
        {
            Caption = 'Jack Henry Private Key (PEM)';
            DataClassification = CustomerContent;
        }

        field(10; FunctionKey; Text[500])
        {
            Caption = 'Function App Key (code parameter)';
            DataClassification = CustomerContent;
        }

        field(11; "JH REST API URL"; Text[250])
        {
            Caption = 'Jack Henry REST API URL';
            DataClassification = CustomerContent;
        }

        field(12; "InstRtId"; Text[20])
        {
            Caption = 'Institution Routing ID (InstRtId)';
            DataClassification = CustomerContent;
            ToolTip = 'ABA routing number for jXchange - e.g., 011001276';
        }

        field(13; "InstEnv"; Text[20])
        {
            Caption = 'Institution Environment (InstEnv)';
            DataClassification = CustomerContent;
            ToolTip = 'Core environment for jXchange - e.g., TEST, Ovation, UAT';
        }

        field(14; "ValidConsmName"; Text[100])
        {
            Caption = 'Valid Consumer Name';
            DataClassification = CustomerContent;
            ToolTip = 'Provided by Jack Henry for jXchangeHdr';
        }

        field(15; "ValidConsmProd"; Text[100])
        {
            Caption = 'Valid Consumer Product';
            DataClassification = CustomerContent;
            ToolTip = 'Provided by Jack Henry for jXchangeHdr';
        }

        field(16; "GL AcctId"; Text[20])
        {
            Caption = 'GL Account ID';
            DataClassification = CustomerContent;
            ToolTip = 'Jack Henry GL account ID to search (e.g., 1090). DEPRECATED - Use GL Search fields below.';
        }

        field(17; "Journal Template"; Code[10])
        {
            Caption = 'Journal Template Name';
            DataClassification = CustomerContent;
            TableRelation = "Gen. Journal Template";
            ToolTip = 'Journal template where GL entries will be imported';
        }

        field(18; "Journal Batch"; Code[10])
        {
            Caption = 'Journal Batch Name';
            DataClassification = CustomerContent;
            ToolTip = 'Journal batch where GL entries will be imported';
        }

        // GL History Search Parameters - At least ONE is required
        field(50100; "GL Search AcctId"; Code[20])
        {
            Caption = 'GL Search Account ID';
            DataClassification = CustomerContent;
            ToolTip = 'Account ID to search for GL history records. At least one search criterion is required.';
        }

        field(50101; "GL Search BatchNum"; Code[20])
        {
            Caption = 'GL Search Batch Number';
            DataClassification = CustomerContent;
            ToolTip = 'Batch Number to search for GL history records. At least one search criterion is required.';
        }

        field(50102; "GL Search BrCode"; Code[20])
        {
            Caption = 'GL Search Branch Code';
            DataClassification = CustomerContent;
            ToolTip = 'Branch Code to search for GL history records. At least one search criterion is required.';
        }

        field(50103; "GL Search GLCostCtr"; Code[20])
        {
            Caption = 'GL Search Cost Center';
            DataClassification = CustomerContent;
            ToolTip = 'Cost Center to search for GL history records. At least one search criterion is required.';
        }

        field(50104; "GL Search GLProdCode"; Code[20])
        {
            Caption = 'GL Search Product Code';
            DataClassification = CustomerContent;
            ToolTip = 'Product Code to search for GL history records. At least one search criterion is required.';
        }

        field(50105; "GL Search Start Date"; Date)
        {
            Caption = 'GL Search Start Date';
            DataClassification = CustomerContent;
            ToolTip = 'Start date for the date range filter (optional).';
        }

        field(50106; "GL Search End Date"; Date)
        {
            Caption = 'GL Search End Date';
            DataClassification = CustomerContent;
            ToolTip = 'End date for the date range filter (optional).';
        }

        field(50107; "GL Search LowAmt"; Decimal)
        {
            Caption = 'GL Search Minimum Amount';
            DataClassification = CustomerContent;
            ToolTip = 'Minimum amount filter (optional).';
        }

        field(50108; "GL Search HighAmt"; Decimal)
        {
            Caption = 'GL Search Maximum Amount';
            DataClassification = CustomerContent;
            ToolTip = 'Maximum amount filter (optional).';
        }

        field(50109; "GL Search SrtMthd"; Code[20])
        {
            Caption = 'GL Search Sort Method';
            DataClassification = CustomerContent;
            ToolTip = 'Sort method: PostDt, EffDt, or Amt (optional).';
        }

        field(50110; "GL Search MemoPostInc"; Code[20])
        {
            Caption = 'GL Search Memo Post Include';
            DataClassification = CustomerContent;
            ToolTip = 'Include memo posts: Excl (default), Only, or True (optional).';
        }
    }

    keys
    {
        key(PK; "AzureTenantId")
        {
            Clustered = true;
        }
    }
}