import React, { useState } from "react";

import {
  jobAutoGenerateAiSummariesOptions,
  AutoGenerateAiSummaries,
} from "@ats/src/lib/newLookups";

import SettingsContainer from "@ats/src/components/shared/SettingsContainer";
import FormSection from "@ats/src/components/forms/FormSection";
import FormSelect from "@ats/src/components/forms/FormSelect";
import Button from "@ats/src/components/shared/Button";
import { useToastContext } from "@shared/context/ToastContext";
import { useUpdateJob } from "@shared/queryHooks/useJob";

function JobSetupAiSettings(props) {
  const { setIsDirty, job: passedJob } = props;
  const addToast = useToastContext();
  const { mutate: updateJob, isLoading: isLoadingUpdateJob } = useUpdateJob();

  const [autoGenerateSetting, setAutoGenerateSetting] = useState<AutoGenerateAiSummaries>(
    passedJob.autoGenerateAiSummaries || "default",
  );

  const onFormInputChange = (name: string, value: AutoGenerateAiSummaries) => {
    setAutoGenerateSetting(value);
    setIsDirty(true);
  };

  const onSubmit = (e) => {
    e.preventDefault();

    updateJob(
      { id: passedJob.id, autoGenerateAiSummaries: autoGenerateSetting },
      {
        onSuccess: () => {
          setIsDirty(false);
          addToast({ title: "Plato AI settings updated", kind: "success" });
        },
        onError: (error: any) => {
          addToast({
            title: error?.data?.errors?.general?.[0] || "Could not update Plato AI settings",
            kind: "warning",
            delay: 10000,
          });
        },
      },
    );
  };

  const BottomBarContent = (
    <Button
      className="submit-button"
      type="button"
      size="medium"
      onClick={onSubmit}
      loading={isLoadingUpdateJob}
      aria-label="Save changes"
    >
      Save changes
    </Button>
  );

  return (
    <SettingsContainer
      title="Plato AI settings"
      description="Configure Plato for this job. Each successful Plato review consumes one credit from your organization's balance."
      bottomBar={BottomBarContent}
    >
      <FormSection title="Plato reviews">
        <FormSelect
          onChange={onFormInputChange}
          name="autoGenerateAiSummaries"
          label="Auto-generation"
          description="Automatically generate a Plato review for each new applicant to this job."
          value={autoGenerateSetting}
          options={jobAutoGenerateAiSummariesOptions}
        />
      </FormSection>
    </SettingsContainer>
  );
}

export default JobSetupAiSettings;
