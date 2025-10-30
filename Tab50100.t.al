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
            ToolTip = 'Jack Henry GL account ID to search (e.g., 1090)';
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
    }

    keys
    {
        key(PK; "AzureTenantId")
        {
            Clustered = true;
        }
    }
}