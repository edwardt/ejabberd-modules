-ifndef(EJABBERD_AUTH_SPARK_HRL).
-define(EJABBERD_AUTH_SPARK_HRL, true).

-record(communitybrandId, {
    environment :: binary(),
	communityId :: integer(),
	brandId :: integer(),
	name :: binary()
}).

-record(ejabberd_auth_spark_config, {
    environment :: binary(),
	spark_api_endpoint :: binary(),
	spark_app_id :: binary(),
	spark_client_secret :: binary(),
	spark_create_oauth_accesstoken :: binary(),
	auth_profile_miniProfile :: binary(),
	profile_memberstatus :: binary(),
	validate_conversation_token ::binary(),
	send_im_mail_message ::binary(),
	community_brandId_dict ::list()
}).


-export_records([ejabberd_auth_spark_config, communitybrandId]).


-endif.
