page 50101 "JH Integration Setup Card"
{
    PageType = Card;
    SourceTable = "JH Integration Setup";
    Caption = 'Jack Henry Integration Setup';
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            group(Group)
            {
                Caption = 'Azure Function App Settings';

                field("TokenBrokerUrl"; Rec.TokenBrokerUrl)
                {
                    ApplicationArea = All;
                    Caption = 'Token Broker URL (without ?code=)';
                    ToolTip = 'Example: https://yourapp.azurewebsites.net/api/GetToken';
                }

                field("FunctionKey"; Rec.FunctionKey)
                {
                    ApplicationArea = All;
                    Caption = 'Function App Key (ONLY the key, not a URL)';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Get this from Azure Portal > Function App > App Keys > Host keys. Should be a long random string like: q5E7xKz9mN3pL8r...';
                }
            }

            group(Group3)
            {
                Caption = 'Business Central Azure AD (if needed)';

                field("AzureTenantId"; Rec.AzureTenantId)
                {
                    ApplicationArea = All;
                }

                field("BC Client Id"; Rec."BC Client Id")
                {
                    ApplicationArea = All;
                }

                field("BC Client Secret"; Rec."BC Client Secret")
                {
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                }

                field("Function App Audience"; Rec."Function App Audience")
                {
                    ApplicationArea = All;
                }
            }

            group(Group2)
            {
                Caption = 'Jack Henry jXchange Settings';

                field("JH REST API URL"; Rec."JH REST API URL")
                {
                    ApplicationArea = All;
                    Caption = 'REST API URL (Recommended)';
                    ToolTip = 'Jack Henry MuleSoft REST API endpoint for your operation';
                    Importance = Promoted;
                }

                field("Middleware URL"; Rec."Middleware URL")
                {
                    ApplicationArea = All;
                    Caption = 'SOAP URL (Alternative)';
                    ToolTip = 'jXchange ServiceGateway SOAP URL: https://jx.jackhenry.com/jXchange/2008/ServiceGateway/OAuth/ServiceGateway.svc';
                    Visible = false;
                }

                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                    Caption = 'Jack Henry Client ID';
                }

                field("Private Key"; Rec."PrivateKey")
                {
                    ApplicationArea = All;
                    Editable = true;
                    MultiLine = true;
                    ExtendedDatatype = Masked;
                }

                field("InstRtId"; Rec."InstRtId")
                {
                    ApplicationArea = All;
                    ToolTip = 'Institution Routing ID - e.g., 011001276 for SilverLake DMZ';
                }

                field("InstEnv"; Rec."InstEnv")
                {
                    ApplicationArea = All;
                    ToolTip = 'Institution Environment - e.g., TEST or Ovation';
                }

                field("ValidConsmName"; Rec."ValidConsmName")
                {
                    ApplicationArea = All;
                    ToolTip = 'Valid Consumer Name provided by Jack Henry';
                }

                field("ValidConsmProd"; Rec."ValidConsmProd")
                {
                    ApplicationArea = All;
                    ToolTip = 'Valid Consumer Product provided by Jack Henry';
                }

                field("Scope"; Rec."Scope")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }

            group(GroupGL)
            {
                Caption = 'GL History Search Parameters';

                field("GL AcctId"; Rec."GL AcctId")
                {
                    ApplicationArea = All;
                    ToolTip = 'Jack Henry GL account ID to search (e.g., 1090). Leave blank to search all GL transactions by date range (last 90 days).';
                    Importance = Promoted;
                }
            }

            group(GroupJournal)
            {
                Caption = 'Journal Import Settings';

                field("Journal Template"; Rec."Journal Template")
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the journal template where GL entries will be imported';
                    Importance = Promoted;
                }

                field("Journal Batch"; Rec."Journal Batch")
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the journal batch where GL entries will be imported';
                    Importance = Promoted;
                    TableRelation = "Gen. Journal Batch"."Name" where("Journal Template Name" = field("Journal Template"));
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(TestTokenOnly)
            {
                Caption = 'Test Token Generation';
                Image = Permission;
                ToolTip = 'Test if we can get an access token from Jack Henry';
                
                trigger OnAction()
                var
                    TokenService: Codeunit "JH Token Service";
                    AccessToken: Text;
                begin
                    AccessToken := TokenService.GetToken();
                    
                    if AccessToken <> '' then
                        Message('✓ Token successfully retrieved!\n\nToken (first 50 chars): %1...', CopyStr(AccessToken, 1, 50))
                    else
                        Error('Failed to retrieve access token.');
                end;
            }

            action(ImportAndPost)
            {
                Caption = 'Import & Post GL Entries';
                Image = PostDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Get GL entries from Jack Henry and post them to BC';

                trigger OnAction()
                var
                    ImportHelper: Codeunit "JH GL Journal Import Helper";
                begin
                    ImportHelper.ImportAndPostJournalEntries();
                end;
            }

            action(ImportOnly)
            {
                Caption = 'Import GL Entries (Don''t Post)';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Get GL entries from Jack Henry without posting';

                trigger OnAction()
                var
                    ImportHelper: Codeunit "JH GL Journal Import Helper";
                begin
                    ImportHelper.ImportJournalEntries();
                    Message('Entries imported. Review them in General Journal before posting.');
                end;
            }
        }
    }
}