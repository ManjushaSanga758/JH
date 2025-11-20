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

                group(GroupGLRequired)
                {
                    Caption = 'Search Criteria (At Least ONE Required)';
                    InstructionalText = 'You must provide at least one of these search criteria to retrieve GL history records.';

                    field("GL Search AcctId"; Rec."GL Search AcctId")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Account ID to search for GL history records. Example: 1090';
                        Importance = Promoted;
                    }

                    field("GL Search BatchNum"; Rec."GL Search BatchNum")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Batch Number to search for GL history records. Example: 907';
                        Importance = Promoted;
                    }

                    field("GL Search BrCode"; Rec."GL Search BrCode")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Branch Code to search for GL history records. Example: 1';
                        Importance = Promoted;
                    }

                    field("GL Search GLCostCtr"; Rec."GL Search GLCostCtr")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Cost Center to search for GL history records. Example: 100';
                        Importance = Promoted;
                    }

                    field("GL Search GLProdCode"; Rec."GL Search GLProdCode")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Product Code to search for GL history records. Example: 999';
                        Importance = Promoted;
                    }
                }

                group(GroupGLOptional)
                {
                    Caption = 'Optional Filters';

                    field("GL Search Start Date"; Rec."GL Search Start Date")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Start date for the date range filter. Format: YYYY-MM-DD';
                    }

                    field("GL Search End Date"; Rec."GL Search End Date")
                    {
                        ApplicationArea = All;
                        ToolTip = 'End date for the date range filter. Format: YYYY-MM-DD';
                    }

                    field("GL Search LowAmt"; Rec."GL Search LowAmt")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Minimum amount filter. Example: 1000';
                    }

                    field("GL Search HighAmt"; Rec."GL Search HighAmt")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Maximum amount filter. Example: 50000';
                    }

                    field("GL Search SrtMthd"; Rec."GL Search SrtMthd")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Sort method: PostDt (posting date), EffDt (effective date), or Amt (amount)';
                    }

                    field("GL Search MemoPostInc"; Rec."GL Search MemoPostInc")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Include memo posts: Excl (exclude, default), Only (only memo posts), or True (include all)';
                    }
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

            action(TestParmValSrch)
            {
                Caption = 'Open Parameter Discovery';
                Image = List;
                ToolTip = 'Open a page to discover valid parameter values (Branch Codes, Cost Centers, Product Codes) from Jack Henry.';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Page.Run(Page::"JH Parameter Discovery");
                end;
            }

            action(TestSvcDictSrch)
            {
                Caption = 'Discover Service Structure';
                Image = TestReport;
                ToolTip = 'Call SvcDictSrch API to discover GLHistSrch service structure and available fields.';
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    JHHelper: Codeunit "JH GL Journal Import Helper";
                    ResponseText: Text;
                begin
                    ResponseText := JHHelper.CallSvcDictSrch();
                    Message('SvcDictSrch Response:\n\n%1', CopyStr(ResponseText, 1, 3000));
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